# frozen_string_literal: true

require 'test_helper'

class UserTest < ActiveSupport::TestCase
  setup do
    # Create a constituent user to test against for uniqueness
    @existing_constituent = create(:constituent, email: 'unique.constituent@example.com', phone: '555-111-2222')
  end

  test 'admins scope works as expected' do
    # Just verify the scope SQL structure is what we expect
    scope_sql = User.admins.to_sql
    assert_match(/WHERE.+"users"\."type" = 'Users::Administrator'/, scope_sql)
  end

  test 'should not save constituent with duplicate email' do
    constituent = build(:constituent, email: 'unique.constituent@example.com') # Same email as @existing_constituent
    assert_not constituent.save, 'Saved constituent with duplicate email'
    assert_includes constituent.errors[:email], 'has already been taken'
  end

  test 'should save constituent with unique email' do
    constituent = build(:constituent, email: 'another.constituent@example.com')
    assert constituent.save, "Did not save constituent with unique email: #{constituent.errors.full_messages.join(', ')}"
  end

  test 'should not save constituent with duplicate phone number' do
    constituent = build(:constituent, phone: '555-111-2222') # Same phone as @existing_constituent
    assert_not constituent.save, 'Saved constituent with duplicate phone number'
    assert_includes constituent.errors[:phone], 'has already been taken'
  end

  test 'should save constituent with unique phone number' do
    constituent = build(:constituent, phone: '555-333-4444')
    assert constituent.save, "Did not save constituent with unique phone number: #{constituent.errors.full_messages.join(', ')}"
  end

  test 'should save constituent with blank phone number' do
    constituent = build(:constituent, phone: '')
    assert constituent.save, "Did not save constituent with blank phone number: #{constituent.errors.full_messages.join(', ')}"
  end

  test 'should save multiple constituents with blank phone numbers' do
    create(:constituent, phone: nil) # First constituent with nil phone
    constituent2 = build(:constituent, phone: '') # Second constituent with blank phone
    assert constituent2.save, "Did not save second constituent with blank phone number: #{constituent2.errors.full_messages.join(', ')}"
  end

  test 'phone number formatting runs before validation' do
    # Test with unformatted number that matches existing formatted number
    constituent = build(:constituent, phone: '(555) 111.2222') # Unformatted, but same digits as @existing_constituent
    assert_not constituent.save, 'Saved constituent with unformatted but duplicate phone number'
    assert_includes constituent.errors[:phone], 'has already been taken', 'Phone formatting did not run before uniqueness validation'
    assert_equal '555-111-2222', constituent.phone, 'Phone number was not formatted correctly'
  end
end
