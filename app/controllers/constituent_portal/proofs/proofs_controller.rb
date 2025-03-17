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
class ConstituentPortal::Proofs::ProofsController < ApplicationController
      # Tell Rails to look for views in the new location
      prepend_view_path "app/views/constituent_portal/proofs"
      before_action :authenticate_user!
      before_action :require_constituent!
      before_action :set_application
      before_action :ensure_can_submit_proof
      before_action :check_rate_limit, only: [ :resubmit ]
      skip_before_action :verify_authenticity_token, only: [ :direct_upload ]

      def new
        @proof_type = params[:proof_type]
        authorize_proof_access!
      end

      def direct_upload
        blob = ActiveStorage::Blob.create_before_direct_upload!(blob_params)
        render json: direct_upload_json(blob)
      rescue ActionController::ParameterMissing => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def resubmit
        Rails.logger.debug "RESUBMIT PROOF: application_id=#{params[:application_id]}, proof_type=#{params[:proof_type]}"

        authorize_proof_access!
        Rails.logger.debug "PROOF ACCESS AUTHORIZED"

        ActiveRecord::Base.transaction do
          attach_and_update_proof
          Rails.logger.debug "PROOF ATTACHED AND UPDATED"

          track_submission
          Rails.logger.debug "SUBMISSION TRACKED"
        end

        # Set flash and keep it through redirects
        flash[:notice] = "Proof submitted successfully"
        flash.keep(:notice)
        redirect_to resubmit_proof_document_constituent_portal_application_path(@application)
      rescue RateLimit::ExceededError
        # Set flash and keep it through redirects
        flash[:alert] = "Please wait before submitting another proof"
        flash.keep(:alert)
        redirect_to resubmit_proof_document_constituent_portal_application_path(@application)
      rescue StandardError => e
        Rails.logger.error "ERROR IN RESUBMIT: #{e.class.name}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
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
        @application = current_user.applications.find(params[:application_id])
      rescue ActiveRecord::RecordNotFound
        redirect_to constituent_portal_dashboard_path, alert: "Application not found"
      end

      def require_constituent!
        unless current_user&.constituent?
          redirect_to root_path, alert: "Access denied"
        end
      end

      def ensure_can_submit_proof
        unless @application.can_submit_proof?
          redirect_to constituent_portal_application_path(@application),
            alert: "Cannot submit proof at this time"
        end
      end

      def authorize_proof_access!
        unless valid_proof_type? && can_modify_proof?
          redirect_to constituent_portal_application_path(@application),
            alert: "Invalid proof type or status"
        end
      end

      def check_rate_limit
        RateLimit.check!(:proof_submission, current_user.id)
      end

      # Delegates the actual proof attachment to ProofAttachmentService
      # This ensures a consistent approach to attachment across the application
      # Both constituent portal and paper applications use the same service
      def attach_and_update_proof
        result = ProofAttachmentService.attach_proof(
          application: @application,
          proof_type: params[:proof_type],
          blob_or_file: params[:"#{params[:proof_type]}_proof"],
          status: :not_reviewed,
          admin: nil,
          metadata: {
            ip_address: request.remote_ip,
            submission_method: :web,
            user_agent: request.user_agent
          }
        )
        
        unless result[:success]
          Rails.logger.error "Failed to attach proof: #{result[:error]&.message}"
          raise "Failed to attach proof: #{result[:error]&.message}"
        end
      end

      def track_submission
        # Create Event for application audit log
        event = Event.create!(
          user: current_user,
          action: "proof_submitted",
          metadata: {
            application_id: @application.id,
            proof_type: params[:proof_type]
          }
        )
        Rails.logger.debug "EVENT CREATED: #{event.inspect}"

        # Create ProofSubmissionAudit for policy audit log
        audit = ProofSubmissionAudit.create!(
          application: @application,
          user: current_user,
          proof_type: params[:proof_type],
          submission_method: :web,
          ip_address: request.remote_ip,
          metadata: {
            user_agent: request.user_agent,
            submission_method: "web"
          }
        )
        Rails.logger.debug "AUDIT CREATED: #{audit.inspect}"
      end

      def valid_proof_type?
        %w[income residency].include?(params[:proof_type])
      end

      def can_modify_proof?
        case params[:proof_type]
        when "income"
          @application.rejected_income_proof?
        when "residency"
          @application.rejected_residency_proof?
        end
      end
end
