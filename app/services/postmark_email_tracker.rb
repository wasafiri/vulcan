class PostmarkEmailTracker
  RETRY_COUNT = 3
  RETRY_DELAY = 1.second

  def self.fetch_status(message_id)
    with_retries do
      client = Postmark::ApiClient.new(ENV.fetch('POSTMARK_API_TOKEN'))
      
      # Get message details
      begin
        message = client.get_message(message_id)
        status = message['Status']
        delivered_at = message['DeliveredAt'] ? Time.parse(message['DeliveredAt']) : nil
      rescue => e
        Rails.logger.error("Error fetching message details: #{e.message}")
        status = 'error'
        delivered_at = nil
      end
      
      # Get open information
      begin
        opens_response = client.get_message_opens(message_id, count: 1, offset: 0)
        first_open = opens_response['Opens'].first if opens_response['Opens'].present?
        
        if first_open
          opened_at = Time.parse(first_open['ReceivedAt'])
          open_details = first_open
        else
          opened_at = nil
          open_details = nil
        end
      rescue => e
        Rails.logger.error("Error fetching message opens: #{e.message}")
        opened_at = nil
        open_details = nil
      end
      
      {
        status: status,
        delivered_at: delivered_at,
        opened_at: opened_at,
        open_details: open_details
      }
    end
  end

  private

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
end
