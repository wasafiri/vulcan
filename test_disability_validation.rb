#!/usr/bin/env ruby
# This script tests the disability validation changes

require_relative 'config/environment'

puts "Testing disability validation changes..."

# Create a new constituent without setting a disability
constituent = Constituent.new(
  email: "test_user_#{Time.now.to_i}@example.com",
  password: "password123",
  first_name: "Test",
  last_name: "User"
)

# Try to save the constituent
if constituent.save
  puts "✅ Constituent saved successfully without setting a disability"
else
  puts "❌ Constituent could not be saved: #{constituent.errors.full_messages.join(', ')}"
end

# Try to change the constituent to an admin
constituent.type = "Admin"
if constituent.save
  puts "✅ Constituent changed to admin successfully"
else
  puts "❌ Constituent could not be changed to admin: #{constituent.errors.full_messages.join(', ')}"
end

# Create a new application for the constituent
application = Application.new(
  user: constituent,
  application_date: Date.today,
  status: "draft",
  household_size: 1,
  annual_income: 30000,
  maryland_resident: true,
  self_certify_disability: true
)

# Try to save the application as draft
if application.save
  puts "✅ Application saved as draft successfully"
else
  puts "❌ Application could not be saved as draft: #{application.errors.full_messages.join(', ')}"
end

# Try to submit the application without setting a disability
application.status = "in_progress"
if application.save
  puts "❌ Application submitted without disability (this should fail)"
else
  puts "✅ Application submission failed as expected: #{application.errors.full_messages.join(', ')}"
end

# Set a disability and try again
constituent.hearing_disability = true
constituent.save!
if application.save
  puts "✅ Application submitted successfully after setting a disability"
else
  puts "❌ Application could not be submitted: #{application.errors.full_messages.join(', ')}"
end

puts "Test completed."
