# frozen_string_literal: true

namespace :letters do
  desc "Check for email templates that don't have corresponding letter templates"
  task check_consistency: :environment do
    puts "Checking for email templates without corresponding letter templates...\n\n"

    # Directory paths
    email_dirs = [
      Rails.root.join('app/views/application_notifications_mailer'),
      Rails.root.join('app/views/evaluator_mailer'),
      Rails.root.join('app/views/training_session_notifications_mailer'),
      Rails.root.join('app/views/user_mailer'),
      Rails.root.join('app/views/vendor_notifications_mailer'),
      Rails.root.join('app/views/voucher_notifications_mailer')
    ]

    letter_dir = Rails.root.join('app/views/letters')

    # Get all email template names (excluding layouts, shared, and partials)
    email_templates = []
    email_dirs.each do |dir|
      next unless Dir.exist?(dir)

      Dir.glob("#{dir}/*.html.erb").each do |file|
        basename = File.basename(file, '.html.erb')
        next if basename.start_with?('_') # Skip partials

        email_templates << basename
      end

      Dir.glob("#{dir}/*.text.erb").each do |file|
        basename = File.basename(file, '.text.erb')
        next if basename.start_with?('_') # Skip partials

        email_templates << basename
      end
    end

    email_templates.uniq!

    # Get letter template names
    letter_templates = []
    if Dir.exist?(letter_dir)
      Dir.glob("#{letter_dir}/*.html.erb").each do |file|
        basename = File.basename(file, '.html.erb')
        next if basename.start_with?('_') # Skip partials

        letter_templates << basename
      end
    end

    # Check if PrintQueueItem has corresponding letter types
    print_queue_types = PrintQueueItem.letter_types.keys

    # Find email templates without letter templates
    missing_letters = []
    email_templates.each do |template|
      next if letter_templates.include?(template) ||
              print_queue_types.include?(template) ||
              %w[proof_needs_review_reminder new_evaluation_assigned].include?(template) # Admin-only

      missing_letters << template
    end

    if missing_letters.empty?
      puts 'All email templates have corresponding letter templates! ✅'
    else
      puts "The following email templates don't have corresponding letter templates:"
      puts '==============================================================='
      missing_letters.each do |template|
        puts "  - #{template}"
      end
      puts "\nConsider adding letter templates for these email types to ensure users with letter preference receive all notifications."
    end

    puts "\nPrintQueueItem letter types: #{print_queue_types.join(', ')}"
    puts "Letter templates: #{letter_templates.join(', ')}"
  end
end
