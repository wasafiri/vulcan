# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.4.2'

# authentication
gem 'authentication-zero'
# gem for hosting images & getting ocr functionality
gem 'aws-sdk-s3'
# for fax capabilities
gem 'twilio-ruby', '~> 7.5.1'
# use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem 'bcrypt', '~> 3.1.20'
# reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false
# bundle and process CSS [https://github.com/rails/cssbundling-rails]
gem 'cssbundling-rails'
# build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'
# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem 'kamal', require: false
# use postgresql as the database for Active Record
gem 'pg', '~> 1.5', '>= 1.5.9'
# gem for sending out emails
gem 'postmark-rails', '~> 0.22.1'
# the modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem 'propshaft'
# use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 6.6.0'
# rails framework
gem 'rails', '~> 8.0.2'
# gem for creating zip files
gem 'rubyzip', '3.0.0.rc2'
# hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem 'stimulus-rails'
# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false
# hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem 'turbo-rails'
# pagination capability
gem 'pagy'
# ruby pdf generation library
gem 'prawn', '~> 2.5'
# pdf extraction, display, etc capability
gem 'mupdf', '~> 1.0'
# CSV processing, representing rows as Ruby hashes for easy integration with ActiveRecord
gem 'smarter_csv'
# windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data'

# use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem 'solid_cable'
gem 'solid_cache'
gem 'solid_queue'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem 'image_processing', '~> 1.2'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', require: 'debug/prelude'
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', '~> 7.0', require: false
  gem 'jsbundling-rails'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'better_html', '~> 2.1', '>= 2.1.1'
  gem 'bullet'
  gem 'erb_lint'
  gem 'letter_opener'
  gem 'rubocop'
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-rails'
  gem 'solargraph'
  gem 'web-console'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem 'capybara'
  gem 'database_cleaner-active_record'
  gem 'factory_bot_rails'
  gem 'minitest-rails', '~> 8.0.0'
  gem 'mocha', require: false
  gem 'rails-controller-testing'
  gem 'selenium-webdriver'
end
