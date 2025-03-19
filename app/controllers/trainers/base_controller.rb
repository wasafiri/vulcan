class Trainers::BaseController < ApplicationController
  include Pagy::Backend
  before_action :require_trainer

  private

  def require_trainer
    unless current_user&.type == "Trainer" || current_user&.has_capability?(:can_train) || current_user&.admin?
      redirect_to root_path, alert: "You must be a trainer to access this area"
    end
  end
end
