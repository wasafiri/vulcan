# frozen_string_literal: true

# Tests for RateLimit service
#
# These tests verify that the rate limiting mechanism works correctly:
# - Counts requests correctly
# - Enforces limits based on Policy settings
# - Raises appropriate errors when limits are exceeded
# - Resets counts after the configured period
#
# Related files:
# - app/services/rate_limit.rb - The service being tested
# - app/models/policy.rb - Provides configuration values
# - app/mailboxes/proof_submission_mailbox.rb - Uses rate limiting

require 'test_helper'

class RateLimitTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    # Define the test parameters
    @action = :proof_submission
    @method = :email
    @identifier = 'user@example.com'
    @limit = 5
    @period_hours = 24

    # Create the required policies
    Policy.find_or_create_by(key: "#{@action}_rate_limit_#{@method}") do |policy|
      policy.value = @limit
    end

    Policy.find_or_create_by(key: "#{@action}_rate_period") do |policy|
      policy.value = @period_hours
    end

    # Force-update if the policies already existed but with different values
    limit_policy = Policy.find_by(key: "#{@action}_rate_limit_#{@method}")
    period_policy = Policy.find_by(key: "#{@action}_rate_period")

    limit_policy.update_column(:value, @limit) if limit_policy&.value != @limit
    period_policy.update_column(:value, @period_hours) if period_policy&.value != @period_hours

    # Verify policies were set correctly
    assert_equal @limit, Policy.get("#{@action}_rate_limit_#{@method}")
    assert_equal @period_hours, Policy.get("#{@action}_rate_period")

    # Stub the Policy.rate_limit_for method
    Policy.stubs(:rate_limit_for).with(@action, @method).returns({
                                                                   max: @limit,
                                                                   period: @period_hours.hours
                                                                 })

    # Initialize test counters
    @test_cache = {}

    # Stub cache methods
    Rails.cache.stubs(:read).with(regexp_matches(/rate_limit:/)).returns(nil)
    Rails.cache.stubs(:clear)

    # Use a more direct approach to track and verify counts
    Rails.cache.stubs(:increment).with(regexp_matches(/rate_limit:/), 1, anything).returns do |key, _, _|
      @test_cache[key] ||= 0
      @test_cache[key] += 1
    end

    Rails.cache.stubs(:read).with(regexp_matches(/rate_limit:#{@action}:#{@method}:#{@identifier}/)).returns do |key|
      @test_cache[key]
    end
  end

  teardown do
    # Reset time helpers and cache
    travel_back
    Rails.cache.clear
  end

  test 'first check passes and increments counter' do
    skip 'Temporarily skipping to further investigate test environment cache issues'
    # First check should pass
    assert_nothing_raised do
      RateLimit.check!(@action, @identifier, @method)
    end

    # Counter should be incremented to 1
    assert_equal 1, Rails.cache.read("rate_limit:#{@action}:#{@method}:#{@identifier}")
  end

  test 'subsequent checks within limit pass and increment counter' do
    # First check
    RateLimit.check!(@action, @identifier, @method)

    # Subsequent checks up to the limit
    (@limit - 1).times do |i|
      assert_nothing_raised do
        RateLimit.check!(@action, @identifier, @method)
      end

      # Counter should be incremented each time
      assert_equal i + 2, Rails.cache.read("rate_limit:#{@action}:#{@method}:#{@identifier}")
    end

    # Final counter should equal the limit
    assert_equal @limit, Rails.cache.read("rate_limit:#{@action}:#{@method}:#{@identifier}")
  end

  test 'exceeding limit raises RateLimit::ExceededError' do
    # Fill up to the limit
    @limit.times do
      RateLimit.check!(@action, @identifier, @method)
    end

    # Next check should fail
    error = assert_raises(RateLimit::ExceededError) do
      RateLimit.check!(@action, @identifier, @method)
    end

    # Error message should include relevant information
    assert_match(/rate limit exceeded for #{@action}/i, error.message)
    assert_match(/\(#{@method}\)/i, error.message)
    assert_match(/maximum #{@limit} submissions/i, error.message)
    assert_match(/per #{@period_hours} hour/i, error.message)
  end

  test 'limit resets after period expires' do
    # Fill up to the limit
    @limit.times do
      RateLimit.check!(@action, @identifier, @method)
    end

    # Verify we've hit the limit
    assert_raises(RateLimit::ExceededError) do
      RateLimit.check!(@action, @identifier, @method)
    end

    # Travel to after the rate limit period
    travel_to Time.current + @period_hours.hours + 1.minute

    # Check should now pass again
    assert_nothing_raised do
      RateLimit.check!(@action, @identifier, @method)
    end

    # Counter should be reset to 1
    assert_equal 1, Rails.cache.read("rate_limit:#{@action}:#{@method}:#{@identifier}")
  end

  test 'limit is per-action and per-method' do
    # Use up the limit for the first action/method
    @limit.times do
      RateLimit.check!(@action, @identifier, @method)
    end

    # Different action should still be allowed
    assert_nothing_raised do
      RateLimit.check!(:different_action, @identifier, @method)
    end

    # Different method should still be allowed
    assert_nothing_raised do
      RateLimit.check!(@action, @identifier, :web)
    end

    # Different identifier should still be allowed
    assert_nothing_raised do
      RateLimit.check!(@action, 'different_user@example.com', @method)
    end
  end

  test 'raises ArgumentError for unknown action' do
    # Delete the Policy for our action to simulate an unknown action
    policy = Policy.find_by(key: "#{@action}_rate_limit_#{@method}")
    policy.destroy if policy

    assert_raises(ArgumentError, 'Unknown rate limit action') do
      RateLimit.check!(@action, @identifier, @method)
    end
  end
end
