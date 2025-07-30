# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/notification_delivery_stub'

module AdminNamespace
  class TrainingRequestsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      @constituent = users(:constituent_john)
      @application = create(:application, user: @constituent, status: :approved,
                                          household_size: 2, annual_income: 30_000,
                                          maryland_resident: true, self_certify_disability: true)

      # Set Current.user to avoid validation errors in callbacks
      Current.user = @admin
      Current.reset

      # Create a training request notification
      NotificationService.create_and_deliver!(
        type: 'training_requested',
        recipient: @admin,
        actor: @constituent,
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
