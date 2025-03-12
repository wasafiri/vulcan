class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:check_email_status]

  def check_email_status
    if @notification.email_tracking?
      UpdateEmailStatusJob.perform_later(@notification.id)
      
      respond_to do |format|
        format.html do
          flash[:notice] = "Checking email status. This may take a moment."
          redirect_back(fallback_location: root_path)
        end
        format.turbo_stream do
          flash.now[:notice] = "Checking email status. This may take a moment."
          render turbo_stream: [
            turbo_stream.replace("flash", partial: "shared/flash"),
            turbo_stream.append("notification_#{@notification.id}", 
                               partial: "notifications/checking_status")
          ]
        end
      end
    else
      respond_to do |format|
        format.html do
          flash[:alert] = "Cannot check status for this notification."
          redirect_back(fallback_location: root_path)
        end
        format.turbo_stream do
          flash.now[:alert] = "Cannot check status for this notification."
          render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
        end
      end
    end
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html do
        flash[:alert] = "Notification not found."
        redirect_back(fallback_location: root_path)
      end
      format.turbo_stream do
        flash.now[:alert] = "Notification not found."
        render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash")
      end
    end
  end
end
