# frozen_string_literal: true

module Admin
  class GuardianRelationshipsController < Admin::BaseController
    before_action :set_guardian, only: %i[new create]
    before_action :set_relationship, only: [:destroy]

    def new
      @dependent = User.find_by(id: params[:dependent_id]) if params[:dependent_id].present?
      @guardian_relationship = GuardianRelationship.new(
        guardian_user: @guardian,
        dependent_user: @dependent
      )
    end

    def create
      # Find or build dependent user
      dependent_user_id = params[:guardian_relationship][:dependent_id]

      # Create the guardian relationship
      @guardian_relationship = GuardianRelationship.new(
        guardian_id: @guardian.id,
        dependent_id: dependent_user_id,
        relationship_type: params[:guardian_relationship][:relationship_type]
      )

      if @guardian_relationship.save
        redirect_to admin_user_path(@guardian), notice: 'Guardian relationship created successfully.'
      else
        @dependent = User.find_by(id: dependent_user_id) if dependent_user_id.present?
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      guardian = @guardian_relationship.guardian_user
      dependent = @guardian_relationship.dependent_user

      if @guardian_relationship.destroy
        redirect_to admin_user_path(params[:return_to] == 'dependent' ? dependent : guardian),
                    notice: 'Guardian relationship removed successfully.'
      else
        redirect_to admin_user_path(params[:return_to] == 'dependent' ? dependent : guardian),
                    alert: 'Failed to remove guardian relationship.'
      end
    end

    private

    def set_guardian
      @guardian = User.find(params[:guardian_id])
    end

    def set_relationship
      @guardian_relationship = GuardianRelationship.find(params[:id])
    end

    def guardian_relationship_params
      params.require(:guardian_relationship).permit(:dependent_id, :relationship_type)
    end
  end
end
