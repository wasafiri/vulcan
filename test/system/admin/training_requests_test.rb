# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/notification_delivery_stub'

module AdminNamespace
  class TrainingRequestsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      @constituent = users(:constituent_john)
      @application = applications(:one)

      # Set Current.user to avoid validation errors in callbacks
      Current.user = @admin
      @application.update!(status: :approved)
      Current.reset

      # Create a training request notification
      Notification.create!(
        recipient: @admin,
        actor: @constituent,
        action: 'training_requested',
        notifiable: @application,
        metadata: {
          application_id: @application.id,
          constituent_id: @constituent.id,
          constituent_name: @constituent.full_name,
          timestamp: Time.current.iso8601
        }
      )

      # Sign in as admin
      sign_in(@admin)
    end

    teardown do
      Current.reset
    end

    test 'admin can view applications' do
      visit admin_applications_path
      assert_selector 'h1', text: 'Admin Dashboard'

      # Basic verification that the page loaded
      assert_selector '.bg-white'
    end
  end
end
