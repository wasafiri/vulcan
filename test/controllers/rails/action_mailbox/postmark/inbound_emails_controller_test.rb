# frozen_string_literal: true

require 'test_helper'

module Rails
  module ActionMailbox
    module Postmark
      class InboundEmailsControllerTest < ActionDispatch::IntegrationTest
        test 'should accept inbound email with valid signature' do
          # Create a sample inbound email payload
          payload = {
            From: 'sender@example.com',
            To: 'proof@example.com',
            Subject: 'Test Inbound Email',
            TextBody: 'This is a test email body',
            MessageID: 'test-message-id-123'
          }.to_json

          # Mock the signature verification
          Rails::ActionMailbox::Postmark::InboundEmailsController.any_instance.stubs(:verify_authenticity).returns(true)

          # Post the payload to the inbound emails endpoint
          assert_difference -> { ActionMailbox::InboundEmail.count }, 1 do
            post rails_postmark_inbound_emails_url, params: payload, headers: { 'Content-Type' => 'application/json' }
          end

          assert_response :success
        end

        test 'should reject inbound email with invalid signature' do
          # Create a sample inbound email payload
          payload = {
            From: 'sender@example.com',
            To: 'proof@example.com',
            Subject: 'Test Inbound Email',
            TextBody: 'This is a test email body',
            MessageID: 'test-message-id-123'
          }.to_json

          # Mock the signature verification to fail
          Rails::ActionMailbox::Postmark::InboundEmailsController.any_instance.stubs(:verify_authenticity).returns(false)

          # Post the payload to the inbound emails endpoint
          assert_no_difference -> { ActionMailbox::InboundEmail.count } do
            post rails_postmark_inbound_emails_url, params: payload, headers: { 'Content-Type' => 'application/json' }
          end

          assert_response :unauthorized
        end
      end
    end
  end
end
