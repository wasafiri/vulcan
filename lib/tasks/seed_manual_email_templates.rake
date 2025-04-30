# frozen_string_literal: true

namespace :db do
  desc 'Seed EmailTemplate records from manually created template files in db/seeds/email_templates/'
  task seed_manual_email_templates: :environment do
    puts "=== Manual Email Template Seeding START at #{Time.current} ==="

    # Clear existing templates for a fresh start
    EmailTemplate.delete_all
    puts 'Deleted all existing email templates.'

    # Load all template seed files
    require Rails.root.join('db/seeds/email_templates.rb')

    # Display results
    text_count = EmailTemplate.where(format: :text).count
    html_count = EmailTemplate.where(format: :html).count
    total_count = EmailTemplate.count

    puts "Seeded #{total_count} email templates (#{text_count} text, #{html_count} HTML)."
    puts "=== Manual Email Template Seeding END at #{Time.current} ==="
  end
end
