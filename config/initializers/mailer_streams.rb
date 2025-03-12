module MatVulcan
  class MailerStreams
    STREAM_MAPPINGS = {
      notifications: 'notifications',
      transactional: 'outbound',
      broadcast: 'broadcast'
    }.freeze

    class << self
      def for_type(mailer_type)
        STREAM_MAPPINGS.fetch(mailer_type.to_sym, 'outbound')
      end

      def valid_type?(type)
        STREAM_MAPPINGS.key?(type.to_sym)
      end
    end
  end
end
