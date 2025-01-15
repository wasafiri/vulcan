# app/controllers/webhooks/email_events_controller.rb
module Webhooks
  class EmailEventsController < BaseController
    def create
      handler = EmailEventHandler.new(webhook_params)

      if handler.process
        head :ok
      else
        head :unprocessable_entity
      end
    end

    private

    def valid_payload?
      required_fields = %w[event type email]
      required_fields.all? { |field| params[field].present? }
    end

    def webhook_params
      params.permit(
        :event,
        :type,
        :email,
        bounce: [ :type, :diagnostics ],
        complaint: [ :type, :feedback_id ]
      )
    end
  end
end
