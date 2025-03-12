module MessageStreamable
  extend ActiveSupport::Concern

  included do
    class_attribute :message_stream_type
  end

  class_methods do
    def use_message_stream(type)
      raise ArgumentError, "Invalid stream type: #{type}" unless MatVulcan::MailerStreams.valid_type?(type)
      
      self.message_stream_type = type
      before_action :configure_message_stream
    end
  end

  private

  def configure_message_stream
    return unless self.class.message_stream_type
    
    headers['X-PM-Message-Stream'] = MatVulcan::MailerStreams.for_type(self.class.message_stream_type)
  end
end
