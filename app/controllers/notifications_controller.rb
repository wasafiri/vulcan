# NotificationsController handles actions related to email notifications.
class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:check_email_status]

  def check_email_status
    tracking = @notification.email_tracking?
    UpdateEmailStatusJob.perform_later(@notification.id) if tracking

    flash_message = tracking ? 'Checking email status. This may take a moment.' : 'Cannot check status for this notification.'
    render_partials = [turbo_stream.replace('flash', partial: 'shared/flash')]
    render_partials << turbo_stream.append("notification_#{@notification.id}", partial: 'notifications/checking_status') if tracking

    respond_to do |format|
      format.html do
        flash[tracking ? :notice : :alert] = flash_message
        redirect_back(fallback_location: root_path)
      end
      format.turbo_stream do
        flash.now[tracking ? :notice : :alert] = flash_message
        render turbo_stream: render_partials
      end
    end
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html do
        flash[:alert] = 'Notification not found.'
        redirect_back(fallback_location: root_path)
      end
      format.turbo_stream do
        flash.now[:alert] = 'Notification not found.'
        render turbo_stream: turbo_stream.replace('flash', partial: 'shared/flash')
      end
    end
  end
end
