if Rails.env.production?
  module ActionCable
    module SubscriptionAdapter
      class PostgreSQL
        def self.table_name_prefix
          "cable."
        end
      end
    end
  end
end
