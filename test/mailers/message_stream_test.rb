require 'test_helper'

class MessageStreamTest < ActionMailer::TestCase
  test "notifications mailer uses correct message stream" do
    application = applications(:complete)
    constituent = users(:constituent)
    temp_password = "tempPassword123"
    
    email = ApplicationNotificationsMailer.account_created(constituent, temp_password).deliver_later
    
    assert_equal 'notifications', email.header['X-PM-Message-Stream'].value
  end
  
  test "transactional mailer uses correct message stream" do
    user = users(:admin)
    
    email = UserMailer.with(user: user).password_reset.deliver_later
    
    assert_equal 'outbound', email.header['X-PM-Message-Stream'].value
  end
end
