# frozen_string_literal: true

class PostmarkEmailTracker
  RETRY_COUNT = 3
  RETRY_DELAY = 1.second

  def self.fetch_status(message_id)
    with_retries do
      client = Postmark::ApiClient.new(ENV.fetch('POSTMARK_API_TOKEN'))
      status, delivered_at = fetch_message_details(client, message_id)
      opened_at, open_details = fetch_open_info(client, message_id)

      {
        status: status,
        delivered_at: delivered_at,
        opened_at: opened_at,
        open_details: open_details
      }
    end
  end

  def self.fetch_message_details(client, message_id)
    message = client.get_message(message_id)
    status = message['Status']
    delivered_at = message['DeliveredAt'] ? Time.zone.parse(message['DeliveredAt']) : nil
    [status, delivered_at]
  rescue StandardError => e
    Rails.logger.error("Error fetching message details: #{e.message}")
    ['error', nil]
  end

  def self.fetch_open_info(client, message_id)
    opens_response = client.get_message_opens(message_id, count: 1, offset: 0)
    if opens_response['Opens'].present?
      first_open = opens_response['Opens'].first
      opened_at = Time.zone.parse(first_open['ReceivedAt'])
      [opened_at, first_open]
    else
      [nil, nil]
    end
  rescue StandardError => e
    Rails.logger.error("Error fetching message opens: #{e.message}")
    [nil, nil]
  end

  def self.with_retries
    retries = 0
    begin
      yield
    rescue Postmark::ApiError => e
      retries += 1
      if retries <= RETRY_COUNT
        sleep(RETRY_DELAY)
        retry
      else
        Rails.logger.error("Postmark API error after #{retries} attempts: #{e.message}")
        {
          status: 'error',
          delivered_at: nil,
          opened_at: nil,
          open_details: { error: e.message }
        }
      end
    end
  end

  private_class_method :with_retries, :fetch_message_details, :fetch_open_info
end
