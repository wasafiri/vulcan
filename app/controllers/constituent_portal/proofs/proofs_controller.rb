# frozen_string_literal: true

# Controller for handling proof submissions from constituents through the portal
#
# This controller handles the constituent-facing proof submission workflow:
# 1. Initial proof upload setup
# 2. Direct upload for client-side uploading to S3
# 3. Proof resubmission (after rejection)
#
# Note: While this controller handles the UI and workflow for proof submission,
# the actual attachment is delegated to ProofAttachmentService to maintain
# consistency with the paper application submission path. Both constituent portal
# and paper submissions use ProofAttachmentService as the single source of truth
# for proof attachments.
module ConstituentPortal
  module Proofs
    class ProofsController < ApplicationController
      # Tell Rails to look for views in the new location
      prepend_view_path 'app/views/constituent_portal/proofs'
      before_action :authenticate_user!
      before_action :require_constituent!
      before_action :set_application
      before_action :ensure_can_submit_proof
      before_action :authorize_proof_access!, only: [:resubmit] # Add filter for resubmit
      before_action :check_rate_limit, only: [:resubmit]
      skip_before_action :verify_authenticity_token, only: [:direct_upload]

      def new
        @proof_type = params[:proof_type]
        authorize_proof_access!
      end

      def direct_upload
        # Use keyword arguments for create_before_direct_upload! (Rails 6.1+)
        blob = ActiveStorage::Blob.create_before_direct_upload!(**blob_params.to_h.symbolize_keys)
        render json: direct_upload_json(blob)
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def resubmit
        Rails.logger.debug { "RESUBMIT PROOF: application_id=#{params[:application_id]}, proof_type=#{params[:proof_type]}" }

        # The before_action has already run authorize_proof_access!
        # We need to return if it failed to prevent a double render error
        return if performed?

        Rails.logger.debug 'RESUBMIT: PROOF ACCESS AUTHORIZED' # Renamed for consistency

        # Add log before transaction
        Rails.logger.debug 'RESUBMIT: Starting transaction'
        ActiveRecord::Base.transaction do
          # Add log before attach_and_update_proof
          Rails.logger.debug 'RESUBMIT: Calling attach_and_update_proof'
          attach_and_update_proof
          # Add log after attach_and_update_proof
          Rails.logger.debug 'RESUBMIT: Finished attach_and_update_proof' # Renamed for clarity

          # Add log before track_submission
          Rails.logger.debug 'RESUBMIT: Calling track_submission'
          track_submission
          # Add log after track_submission
          Rails.logger.debug 'RESUBMIT: Finished track_submission' # Renamed for clarity
        end
        # Add log after transaction, before redirect
        Rails.logger.debug 'RESUBMIT: Transaction complete, preparing redirect'

        # Set flash and keep it through redirects
        flash[:notice] = 'Proof submitted successfully'
        flash.keep(:notice)
        redirect_to constituent_portal_application_path(@application)
      rescue RateLimit::ExceededError
        # Add log for rate limit error
        Rails.logger.debug 'RESUBMIT: Rate limit exceeded'
        # Set flash and keep it through redirects
        flash[:alert] = 'Please wait before submitting another proof'
        flash.keep(:alert)
        redirect_to constituent_portal_application_path(@application)
      rescue StandardError => e
        Rails.logger.debug 'RESUBMIT: StandardError caught'
        unless Rails.env.test?
          Rails.logger.error "ERROR IN RESUBMIT: #{e.class.name}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
        raise
      end

      private

      def blob_params
        params.require(:blob).permit(:filename, :byte_size, :checksum, :content_type, metadata: {})
      end

      def direct_upload_json(blob)
        {
          signed_id: blob.signed_id,
          direct_upload: {
            url: blob.service_url_for_direct_upload,
            headers: blob.service_headers_for_direct_upload
          }
        }
      end

      def set_application
        # The application ID could be in different params based on the routing
        # In routes.rb: get 'proofs/new/:proof_type', to: 'proofs/proofs#new', as: :new_proof
        # The :id is from the resource-level param, and we need to extract the ID from the URL path
        application_id = params[:application_id]

        # Special handling for the route format
        if application_id.nil? && params[:id].present?
          # When using routes like /constituent_portal/applications/123/proofs/new/income
          # the ID comes through as :id
          application_id = params[:id]
        end

        Rails.logger.info "Looking for application with ID: #{application_id.inspect}, params: #{params.inspect}"

        if application_id.blank?
          Rails.logger.error "Application ID is nil or empty in params: #{params.inspect}"
          redirect_to constituent_portal_dashboard_path, alert: 'Application not found'
          return
        end

        # First try the standard approach
        @application = current_user.applications.find_by(id: application_id)

        # If that fails, try a more flexible query to handle potential type mismatches
        if @application.nil?
          @application = Application.where(id: application_id)
                                    .where(user_id: current_user.id)
                                    .first
        end

        # If we still couldn't find it, redirect
        return unless @application.nil?

        Rails.logger.error "Application not found with ID: #{application_id} for user: #{current_user.id}"
        redirect_to constituent_portal_dashboard_path, alert: 'Application not found'
      end

      def require_constituent!
        return if current_user&.constituent?

        redirect_to root_path, alert: 'Access denied'
      end

      def ensure_can_submit_proof
        return if @application.can_submit_proof?

        redirect_to constituent_portal_application_path(@application),
                    alert: 'Cannot submit proof at this time'
        nil # Add explicit return to prevent code execution after redirect
      end

      def authorize_proof_access!
        # Log the status seen by the filter
        Rails.logger.debug do
          "AUTHORIZE_PROOF_ACCESS: Checking app ##{@application&.id}, income_status=#{@application&.income_proof_status}"
        end
        return if valid_proof_type? && can_modify_proof?

        Rails.logger.debug { 'AUTHORIZE_PROOF_ACCESS: FAILED - Redirecting' } # Log failure
        redirect_to constituent_portal_application_path(@application),
                    alert: 'Invalid proof type or status'
        false # Return false to signal failure
      end

      def check_rate_limit
        RateLimit.check!(:proof_submission, current_user.id)
      rescue RateLimit::ExceededError
        # Set flash and keep it through redirects
        flash[:alert] = 'Please wait before submitting another proof'
        flash.keep(:alert)
        redirect_to constituent_portal_application_path(@application)
        false
      end

      # Delegates the actual proof attachment to ProofAttachmentService
      # This ensures a consistent approach to attachment across the application
      # Both constituent portal and paper applications use the same service
      def attach_and_update_proof
        # Log that we're resubmitting a previously rejected proof
        is_resubmitting = (@application.income_proof_status_rejected? && params[:proof_type] == 'income') ||
                          (@application.residency_proof_status_rejected? && params[:proof_type] == 'residency')

        if is_resubmitting
          Rails.logger.info "Resubmitting previously rejected #{params[:proof_type]} proof for application #{@application.id}"
        end

        # Set thread local variable to communicate resubmission status to validation layer
        Thread.current[:resubmitting_proof] = is_resubmitting

        begin
          result = ProofAttachmentService.attach_proof(
            application: @application,
            proof_type: params[:proof_type],
            blob_or_file: params[:"#{params[:proof_type]}_proof"],
            status: :not_reviewed,
            admin: nil,
            submission_method: :web,
            metadata: {
              ip_address: request.remote_ip,
              user_agent: request.user_agent || 'Rails Testing',
              resubmitting: is_resubmitting # Pass resubmission flag in metadata
            }
          )
        ensure
          # Always reset thread local, even if an exception occurs
          Thread.current[:resubmitting_proof] = nil
        end

        return if result[:success]

        Rails.logger.error "Failed to attach proof: #{result[:error]&.message}"
        raise "Failed to attach proof: #{result[:error]&.message}"
      end

      def track_submission
        # Create Event for application audit log
        event = Event.create!(
          user: current_user,
          action: 'proof_submitted',
          metadata: {
            application_id: @application.id,
            proof_type: params[:proof_type]
          }
        )
        Rails.logger.debug { "EVENT CREATED: #{event.inspect}" }

        # Create ProofSubmissionAudit for policy audit log
        audit = ProofSubmissionAudit.create!(
          application: @application,
          user: current_user,
          proof_type: params[:proof_type],
          submission_method: :web,
          ip_address: request.remote_ip,
          metadata: {
            user_agent: request.user_agent,
            submission_method: 'web'
          }
        )
        Rails.logger.debug { "AUDIT CREATED: #{audit.inspect}" }
      end

      def valid_proof_type?
        %w[income residency].include?(params[:proof_type])
      end

      def can_modify_proof?
        case params[:proof_type]
        when 'income'
          @application.rejected_income_proof?
        when 'residency'
          @application.rejected_residency_proof?
        end
      end
    end
  end
end
