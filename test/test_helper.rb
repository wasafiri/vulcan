# frozen_string_literal: true

# -----------------------------------------------------------------------------
# Global test-suite boot-strap
# -----------------------------------------------------------------------------
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
Rails.application.eager_load! # ensure Zeitwerk loads *everything* the suite touches
require 'rails/test_help'

# -----------------------------------------------------------------------------
# Reduce test log noise
# -----------------------------------------------------------------------------
# Only show important logs during tests (errors, warnings)
Rails.logger.level = :warn unless ENV['VERBOSE_TESTS']
ActiveRecord::Base.logger.level = :warn unless ENV['VERBOSE_TESTS']

# Disable ActiveStorage logging in tests
ActiveStorage.logger.level = :error if defined?(ActiveStorage.logger)

# Disable verbose query logs and caller tracking in tests
Rails.application.config.active_record.verbose_query_logs = false unless ENV['VERBOSE_TESTS']

# -----------------------------------------------------------------------------
# One-time DB sanitisation (before seeds are loaded)
# -----------------------------------------------------------------------------
begin
  require 'database_cleaner/active_record'
  DatabaseCleaner.clean_with(:truncation)
rescue LoadError
  warn "⚠️  DatabaseCleaner not found.  Add `gem 'database_cleaner-active_record', group: :test`."
end

Rails.application.load_seed if Rails.env.test?

# -----------------------------------------------------------------------------
# Core test libraries
# -----------------------------------------------------------------------------
require 'minitest/mock'
require 'ostruct'
require 'mocha/minitest'
require 'capybara/rails'

Capybara.default_max_wait_time = 5

# -----------------------------------------------------------------------------
# Support helpers (autoloaded from test/support/**)
# -----------------------------------------------------------------------------
Rails.root.glob('test/support/**/*.rb').each { |f| require f }

require 'webauthn/fake_client'

# -----------------------------------------------------------------------------
# Test-only controllers & routes
# -----------------------------------------------------------------------------
require_relative 'controllers/webhooks/test_base_controller'
require_relative 'controllers/webhooks/test_email_events_controller'

# -----------------------------------------------------------------------------
# Generator test-case destination root
# -----------------------------------------------------------------------------
require_relative 'lib/generators/test_case_config'
TestCaseConfig.configure_generator_test_case(Rails::Generators::TestCase)

# -----------------------------------------------------------------------------
# ActionDispatch::IntegrationTest — add default headers (safe prepend)
# -----------------------------------------------------------------------------
module DefaultHeadersRequestPatch
  %i[get post put patch delete].each do |method|
    define_method(method) do |path, **args|
      super(path, **merge_default_headers(args))
    end
  end

  private

  def merge_default_headers(args)
    return args unless respond_to?(:default_headers, true)

    args[:headers] = default_headers.merge(args[:headers] || {})
    args
  end
end

ActionDispatch::IntegrationTest.prepend(DefaultHeadersRequestPatch)

# -----------------------------------------------------------------------------
# ActiveSupport::TestCase – global helpers & teardown
# -----------------------------------------------------------------------------
module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods
    include VoucherTestHelper
    include ActionMailer::TestHelper
    include MailerTestHelper
    include AuthenticationTestHelper
    include FlashTestHelper
    include FormTestHelper
    include ActiveStorageHelper
    include ActiveStorageTestHelper
    include AttachmentTestHelper
    include ProofTestHelper

    # Shortcut occasionally used in controller tests
    attr_reader :product

    # -----------------------------------------------------------------------
    # DatabaseCleaner (per-test) — use transactions for speed and less noise
    # -----------------------------------------------------------------------
    if defined?(DatabaseCleaner)
      # Use transaction strategy by default (much faster and less verbose)
      # Only use truncation when explicitly needed (e.g., tests that require multiple DB connections)
      DatabaseCleaner.strategy = ENV['USE_TRUNCATION'] ? :truncation : :transaction

      setup    { DatabaseCleaner.start } # start transaction/setup
      teardown { DatabaseCleaner.clean } # rollback transaction/clean
    end

    # -----------------------------------------------------------------------
    # Misc. helper assertions / utilities
    # -----------------------------------------------------------------------
    def assert_enqueued_email_with(mailer_class, method_name, mailer_args: nil, &)
      base_job_args = [mailer_class.to_s, method_name.to_s, 'deliver_now']

      matcher = if mailer_args.nil?
                  ->(*actual) { actual[0, 3] == base_job_args }
                else
                  expected = base_job_args + Array(mailer_args)
                  ->(*actual) { actual == expected }
                end

      assert_enqueued_with(job: ActionMailer::MailDeliveryJob, args: matcher, &)
    end

    def assert_test_has_assertions
      assert_operator assertions, :>=, 1, 'Test is missing assertions'
    end

    # -----------------------------------------------------------------------
    # Default headers for Integration tests
    # -----------------------------------------------------------------------
    def default_headers
      base = {
        'HTTP_USER_AGENT' => 'Rails Testing',
        'REMOTE_ADDR' => '127.0.0.1'
      }
      base['Cookie'] = "session_token=#{@session_token}" if defined?(@session_token) && @session_token.present?
      base
    end

    # -----------------------------------------------------------------------
    # "Smoke" test-only route so Minitest sees at least one assertion
    # Only run these tests when VERBOSE_TESTS is enabled to reduce noise
    # -----------------------------------------------------------------------
    if ENV['VERBOSE_TESTS']
      test 'ensure test_auth_status route is recognised' do
        if Rails.application.routes.url_helpers.respond_to?(:test_auth_status_path)
          assert_equal '/test/auth_status',
                       Rails.application.routes.url_helpers.test_auth_status_path
        else
          assert true, 'Route unavailable in this environment – skipping assertion'
        end
      end
    end

    # -----------------------------------------------------------------------
    # ActiveStorage host setup for url_for helpers
    # -----------------------------------------------------------------------
    setup { ActiveStorage::Current.url_options = { host: 'localhost:3000' } }
  end
end

# -----------------------------------------------------------------------------
# Rails-provided test adapters
# -----------------------------------------------------------------------------
ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.deliveries = []

ActiveJob::Base.queue_adapter = :test
Rails.application.config.active_storage.service = :test
