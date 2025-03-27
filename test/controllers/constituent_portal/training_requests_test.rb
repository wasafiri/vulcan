# frozen_string_literal: true

require 'test_helper'
require_relative '../../support/notification_delivery_stub'

module ConstituentPortal
  class TrainingRequestsTest < ActionDispatch::IntegrationTest
    setup do
      @constituent = users(:constituent_john)
      @application = applications(:one)

      # Set Current.user to avoid validation errors in callbacks
      Current.user = users(:admin_david)
      @application.update!(status: :approved)
      Current.reset

      # Set up training session policy
      Policy.find_or_create_by(key: 'max_training_sessions').update(value: 3)

      # Set up authentication
      @headers = { 'HTTP_USER_AGENT' => 'Rails Testing', 'REMOTE_ADDR' => '127.0.0.1' }
      post sign_in_path, params: { email: @constituent.email, password: 'password123' }, headers: @headers
      assert_response :redirect
      follow_redirect!

      # Set Current.user for the controller actions
      Current.user = @constituent
    end

    teardown do
      Current.reset
    end

    test 'should create training request notification' do
      # Count admin users to determine expected notification count
      admin_count = User.where(type: 'Admin').count

      assert_difference "Notification.where(action: 'training_requested').count", admin_count do
        post request_training_constituent_portal_application_path(@application)
      end

      assert_redirected_to constituent_portal_dashboard_path
      assert_equal 'Training request submitted. An administrator will contact you to schedule your session.',
                   flash[:notice]

      # Verify notification details
      notification = Notification.where(action: 'training_requested').last
      assert_equal @application, notification.notifiable
      assert_equal @constituent, notification.actor
      assert_equal 'training_requested', notification.action
      assert_not_nil notification.metadata
      assert_equal @application.id, notification.metadata['application_id']
      assert_equal @constituent.id, notification.metadata['constituent_id']
      assert_equal @constituent.full_name, notification.metadata['constituent_name']
    end

    test 'should not create training request if application not approved' do
      # Set Current.user to avoid validation errors in callbacks
      Current.user = users(:admin_david)
      @application.update!(status: :in_progress)
      Current.reset

      assert_no_difference 'Notification.count' do
        post request_training_constituent_portal_application_path(@application)
      end

      assert_redirected_to constituent_portal_dashboard_path
      assert_equal 'Only approved applications are eligible for training.', flash[:alert]
    end

    test 'should not create training request if max sessions reached' do
      # Create 3 training sessions (max allowed)
      3.times do
        TrainingSession.create!(
          application: @application,
          trainer: users(:trainer_jane),
          scheduled_for: 1.day.from_now,
          status: :completed
        )
      end

      assert_no_difference 'Notification.count' do
        post request_training_constituent_portal_application_path(@application)
      end

      assert_redirected_to constituent_portal_dashboard_path
      assert_equal 'You have used all of your available training sessions.', flash[:alert]
    end
  end
end
