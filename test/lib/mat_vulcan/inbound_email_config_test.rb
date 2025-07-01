# frozen_string_literal: true

require 'test_helper'

module MatVulcan
  class InboundEmailConfigTest < ActiveSupport::TestCase
    setup do
      # Save original values
      @original_address = ENV.fetch('INBOUND_EMAIL_ADDRESS', nil)
      @original_provider = ENV.fetch('INBOUND_EMAIL_PROVIDER', nil)

      # Save original module values
      @original_config_address = MatVulcan::InboundEmailConfig.inbound_email_address
      @original_config_provider = MatVulcan::InboundEmailConfig.provider
    end

    teardown do
      # Restore original environment variables
      ENV['INBOUND_EMAIL_ADDRESS'] = @original_address
      ENV['INBOUND_EMAIL_PROVIDER'] = @original_provider

      # Restore original module values
      MatVulcan::InboundEmailConfig.inbound_email_address = @original_config_address
      MatVulcan::InboundEmailConfig.provider = @original_config_provider
    end

    test 'provides correct Postmark configuration by default' do
      # Test that Postmark is the default provider
      assert_equal :postmark, MatVulcan::InboundEmailConfig.provider

      # Test that default address is formatted as expected
      assert_match(/@inbound\.postmarkapp\.com$/, MatVulcan::InboundEmailConfig.inbound_email_address)

      # Test provider_config returns correct values
      config = MatVulcan::InboundEmailConfig.provider_config
      assert_equal :postmark, config[:ingress]
      assert_equal :postmark_inbound_email_hash, config[:config_key]
      assert_equal MatVulcan::InboundEmailConfig.inbound_email_hash, config[:config_value]
    end

    test 'extracts inbound email hash correctly' do
      # Test with standard email format
      MatVulcan::InboundEmailConfig.inbound_email_address = 'test-hash@example.com'
      assert_equal 'test-hash', MatVulcan::InboundEmailConfig.inbound_email_hash

      # Test with complex format
      MatVulcan::InboundEmailConfig.inbound_email_address = 'complex+hash.123@subdomain.example.com'
      assert_equal 'complex+hash.123', MatVulcan::InboundEmailConfig.inbound_email_hash
    end

    test 'extracts domain correctly' do
      MatVulcan::InboundEmailConfig.inbound_email_address = 'test@example.com'
      assert_equal 'example.com', MatVulcan::InboundEmailConfig.inbound_email_domain

      MatVulcan::InboundEmailConfig.inbound_email_address = 'test@sub.example.co.uk'
      assert_equal 'sub.example.co.uk', MatVulcan::InboundEmailConfig.inbound_email_domain
    end

    test 'uses environment variables when available' do
      ENV['INBOUND_EMAIL_ADDRESS'] = 'env-test@example.com'
      ENV['INBOUND_EMAIL_PROVIDER'] = 'mailgun'

      # Force reloading of the module
      load Rails.root.join('config/initializers/01_inbound_email_config.rb')

      # Test values
      assert_equal 'env-test@example.com', MatVulcan::InboundEmailConfig.inbound_email_address
      assert_equal :mailgun, MatVulcan::InboundEmailConfig.provider

      # Test that provider_config adapts correctly
      config = MatVulcan::InboundEmailConfig.provider_config
      assert_equal :mailgun, config[:ingress]
      assert_equal :mailgun_routing_key, config[:config_key]
    end

    test 'using? helper returns correct value' do
      MatVulcan::InboundEmailConfig.provider = :postmark
      assert MatVulcan::InboundEmailConfig.using?(:postmark)
      assert_not MatVulcan::InboundEmailConfig.using?(:sendgrid)

      MatVulcan::InboundEmailConfig.provider = :mailgun
      assert MatVulcan::InboundEmailConfig.using?(:mailgun)
      assert_not MatVulcan::InboundEmailConfig.using?(:postmark)
    end
  end
end
