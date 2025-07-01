# frozen_string_literal: true

class RateLimit
  class ExceededError < StandardError; end

  def self.check!(action, identifier, method = :web)
    new(action, identifier, method).check!
  end

  def initialize(action, identifier, method = :web)
    @action = action
    @identifier = identifier
    @method = method.to_sym
    @limit = Policy.rate_limit_for(@action, @method)
  end

  def check!
    raise ArgumentError, "Unknown rate limit action: #{@action}" unless @limit

    current_count = current_usage_count
    if current_count >= @limit[:max]
      raise ExceededError,
            "Rate limit exceeded for #{@action} (#{@method}): maximum #{@limit[:max]} submissions per #{@limit[:period] / 1.hour} hour(s)"
    end

    increment_count
  end

  private

  def cache_key
    "rate_limit:#{@action}:#{@method}:#{@identifier}"
  end

  def current_usage_count
    Rails.cache.read(cache_key).to_i
  end

  def increment_count
    Rails.cache.increment(cache_key, 1, expires_in: @limit[:period])
  end
end
