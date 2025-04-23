# frozen_string_literal: true

require 'test_helper'

class MessageStreamTest < ActionMailer::TestCase
  test 'notifications mailer uses correct message stream' do
    # Create a constituent user and application using FactoryBot
    application = create(:application, :completed)
    constituent = application.user
    temp_password = 'tempPassword123'

    email = ApplicationNotificationsMailer.account_created(constituent, temp_password)

    assert_equal 'notifications', email.message_stream
  end

  test 'transactional mailer uses correct message stream' do
    # Create an admin user using FactoryBot
    admin = create(:admin)

    email = UserMailer.with(user: admin).password_reset

    assert_equal 'outbound', email.message_stream
  end
end
