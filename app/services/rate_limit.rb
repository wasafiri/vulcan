# app/services/rate_limit.rb
class RateLimit
  class ExceededError < StandardError; end

  LIMITS = {
    proof_submission: { max: 3, period: 1.hour }
  }.freeze

  def self.check!(action, identifier)
    new(action, identifier).check!
  end

  def initialize(action, identifier)
    @action = action
    @identifier = identifier
    @limit = LIMITS[action]
  end

  def check!
    raise ArgumentError, "Unknown rate limit action: #{@action}" unless @limit

    Rails.cache.with_local_cache do
      current_count = get_count
      if current_count >= @limit[:max]
        raise ExceededError, "Rate limit exceeded for #{@action}"
      end
      increment_count
    end
  end

  private

  def cache_key
    "rate_limit:#{@action}:#{@identifier}"
  end

  def get_count
    Rails.cache.read(cache_key).to_i
  end

  def increment_count
    Rails.cache.increment(cache_key, 1, expires_in: @limit[:period])
  end
end
