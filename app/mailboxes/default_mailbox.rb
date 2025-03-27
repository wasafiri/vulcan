# frozen_string_literal: true

class DefaultMailbox < ApplicationMailbox
  def process
    # Log the unrouted email
    Rails.logger.info "Received unrouted email: #{mail.subject} from #{mail.from.first}"

    # Optionally forward to an admin
    # forward_to "admin@example.com"
  end
end
