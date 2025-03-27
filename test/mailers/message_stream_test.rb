# frozen_string_literal: true

require 'test_helper'

class MessageStreamTest < ActionMailer::TestCase
  test 'notifications mailer uses correct message stream' do
    applications(:complete)
    constituent = users(:constituent)
    temp_password = 'tempPassword123'

    email = ApplicationNotificationsMailer.account_created(constituent, temp_password)

    assert_equal 'notifications', email.message_stream
  end

  test 'transactional mailer uses correct message stream' do
    user = users(:admin)

    email = UserMailer.with(user: user).password_reset

    assert_equal 'outbound', email.message_stream
  end
end
