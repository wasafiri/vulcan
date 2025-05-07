# frozen_string_literal: true

namespace :maintenance do
  desc 'Fixes a specific duplicate phone number by incrementing the line number of duplicates (except the first one found by ID).'
  task :fix_duplicate_phone, [:phone_to_fix_arg] => :environment do |_task, args|
    phone_to_fix = args[:phone_to_fix_arg]

    if phone_to_fix.blank?
      puts 'ERROR: Phone number argument is missing.'
      puts "Usage: bundle exec rake 'maintenance:fix_duplicate_phone[XXX-XXX-XXXX]'"
      puts "Example: bundle exec rake 'maintenance:fix_duplicate_phone[443-653-1927]'"
      next
    end

    puts "Starting phone duplication fix for: #{phone_to_fix}"
    users_with_duplicate_phone = User.where(phone: phone_to_fix).order(:id).to_a

    if users_with_duplicate_phone.length <= 1
      puts "No duplicates (or only one record) found for phone: #{phone_to_fix}. No action taken."
      next
    end

    user_to_keep = users_with_duplicate_phone.first
    puts "Keeping User ID: #{user_to_keep.id} (Email: #{user_to_keep.email}) with original phone: #{phone_to_fix}"

    users_to_modify = users_with_duplicate_phone.drop(1)

    users_to_modify.each do |user|
      original_phone = user.phone # This should be the same as phone_to_fix
      puts "Attempting to update phone for User ID: #{user.id} (Email: #{user.email}), original phone: #{original_phone}"

      phone_parts = original_phone.to_s.split('-')
      unless phone_parts.length == 3 && phone_parts.all? { |part| part.match?(/^\d+$/) } && phone_parts[2].length == 4
        puts "User ID: #{user.id} phone '#{original_phone}' does not match expected XXX-XXX-XXXX format or contains non-digits. Skipping modification. Please review manually."
        next
      end

      area_code = phone_parts[0]
      prefix = phone_parts[1]
      current_line_number = phone_parts[2].to_i

      new_phone_candidate = nil
      found_unique_candidate = false
      max_attempts = 100 # Safety break for the loop

      (1..max_attempts).each do |attempt_number|
        prospective_line_number = current_line_number + attempt_number
        # Ensure 4 digits for line number, padding with leading zeros if necessary
        new_line_number_str = prospective_line_number.to_s.rjust(4, '0')
        candidate = "#{area_code}-#{prefix}-#{new_line_number_str}"

        if !User.exists?(phone: candidate)
          new_phone_candidate = candidate
          found_unique_candidate = true
          break
        else
          # This can be noisy if many attempts are needed, consider removing or logging differently for production.
          # puts "Attempt #{attempt_number}: Candidate phone #{candidate} already exists. Trying next increment."
        end
      end

      if found_unique_candidate
        user.update_column(:phone, new_phone_candidate) # Bypasses validations and callbacks
        puts "SUCCESS: User ID: #{user.id} phone updated from #{original_phone} to #{new_phone_candidate}"
      else
        puts "FAILURE: Could not find a unique incremented phone for User ID: #{user.id} (original: #{original_phone}) after #{max_attempts} attempts. Phone NOT changed. Please review manually."
      end
    end
    puts "Finished processing duplicates for original phone: #{phone_to_fix}"
  end
end
