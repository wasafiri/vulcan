# Master seed file to load individual email template seed files
Dir[Rails.root.join('db/seeds/email_templates/*.rb')].each do |seed_file|
  load seed_file
end
puts 'Finished seeding email templates.'
