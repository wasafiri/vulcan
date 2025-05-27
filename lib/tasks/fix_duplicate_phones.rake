# frozen_string_literal: true

namespace :maintenance do
  desc 'For a given phone number, finds duplicate user records, keeps the one with the lowest ID, and sets phone to NULL for the others.'
  task :void_duplicate_phone, [:phone_to_fix_arg] => :environment do |_task, args|
    phone_to_fix = args[:phone_to_fix_arg]

    if phone_to_fix.blank?
      puts 'ERROR: Phone number argument is missing.'
      puts "Usage: bundle exec rake 'maintenance:void_duplicate_phone[XXX-XXX-XXXX]'"
      puts "Example: bundle exec rake 'maintenance:void_duplicate_phone[443-653-1927]'"
      next
    end

    puts "Starting phone voiding process for duplicates of: #{phone_to_fix}"
    users_with_duplicate_phone = User.where(phone: phone_to_fix).order(:id).to_a

    if users_with_duplicate_phone.length <= 1
      puts "No duplicates (or only one record) found for phone: #{phone_to_fix}. No action taken."
      next
    end

    user_to_keep = users_with_duplicate_phone.first
    puts "Keeping User ID: #{user_to_keep.id} (Email: #{user_to_keep.email}) with original phone: #{phone_to_fix}"

    users_to_void = users_with_duplicate_phone.drop(1)

    users_to_void.each do |user|
      original_phone = user.phone # This should be the same as phone_to_fix
      user.update_column(:phone, nil) # Bypasses validations and callbacks
      puts "SUCCESS: User ID: #{user.id} (Email: #{user.email}) phone changed from #{original_phone} to NULL."
    end

    puts "Finished voiding duplicate phone entries for: #{phone_to_fix}"
  end
end
