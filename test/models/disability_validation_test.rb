require "test_helper"

class DisabilityValidationTest < ActiveSupport::TestCase
  test "constituent can be created without disability" do
    constituent = Constituent.new(
      email: "test_user_#{Time.now.to_i}@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User"
    )
    assert constituent.save, "Constituent should be saved without disability"
  end

  test "constituent can be changed to admin without disability" do
    constituent = Constituent.create!(
      email: "test_user_#{Time.now.to_i}@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User"
    )
    constituent.type = "Admin"
    assert constituent.save, "Constituent should be changed to admin without disability"
  end

  test "application can be saved as draft without disability" do
    constituent = Constituent.create!(
      email: "test_user_#{Time.now.to_i}@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User"
    )
    application = Application.new(
      user: constituent,
      application_date: Date.today,
      status: "draft",
      household_size: 1,
      annual_income: 30000,
      maryland_resident: true,
      self_certify_disability: true
    )
    assert application.save, "Application should be saved as draft without disability"
  end

  test "application cannot be submitted without disability" do
    constituent = Constituent.create!(
      email: "test_user_#{Time.now.to_i}@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User"
    )
    application = Application.create!(
      user: constituent,
      application_date: Date.today,
      status: "draft",
      household_size: 1,
      annual_income: 30000,
      maryland_resident: true,
      self_certify_disability: true
    )
    application.status = "in_progress"
    assert_not application.save, "Application should not be submitted without disability"
    assert_includes application.errors.full_messages, "At least one disability must be selected before submitting an application."
  end

  test "application can be submitted with disability" do
    constituent = Constituent.create!(
      email: "test_user_#{Time.now.to_i}@example.com",
      password: "password123",
      first_name: "Test",
      last_name: "User",
      hearing_disability: true
    )
    application = Application.create!(
      user: constituent,
      application_date: Date.today,
      status: "draft",
      household_size: 1,
      annual_income: 30000,
      maryland_resident: true,
      self_certify_disability: true
    )
    application.status = "in_progress"
    assert application.save, "Application should be submitted with disability"
  end
end
