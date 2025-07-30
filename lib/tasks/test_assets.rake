# frozen_string_literal: true

namespace :test do
  desc 'Compile assets for testing'
  task compile_assets: :environment do
    puts 'Compiling CSS assets for tests...'
    system('yarn build:css') || raise('Failed to compile CSS assets')
    puts 'CSS assets compiled successfully!'

    puts 'Compiling JavaScript assets for tests...'
    system('yarn build') || raise('Failed to compile JavaScript assets')
    puts 'JavaScript assets compiled successfully!'
  end

  desc 'Prepare test environment (compile assets, etc.)'
  task prepare: [:compile_assets] do
    puts 'Test environment prepared!'
  end
end

# Hook into the test tasks that actually need compiled assets
task 'test:system' => 'test:compile_assets'
task 'test:all' => 'test:compile_assets'
# Don't hook into regular 'test' task as unit tests don't need compiled assets
