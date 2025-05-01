# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'admins scope works as expected' do
    # Just verify the scope SQL structure is what we expect
    scope_sql = User.admins.to_sql
    assert_match(/WHERE.+"users"\."type" = 'Users::Administrator'/, scope_sql)
  end
end
