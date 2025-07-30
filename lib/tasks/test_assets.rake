# frozen_string_literal: true

namespace :test do
  desc 'Compile assets for testing'
  task compile_assets: :environment do
    puts 'Compiling CSS assets for tests...'
    
    # Try multiple approaches to find and run yarn/tailwindcss
    css_success = false
    
    # Method 1: Try yarn build:css
    if system('which yarn > /dev/null 2>&1') && system('yarn build:css')
      css_success = true
    # Method 2: Try npx tailwindcss directly
    elsif system('which npx > /dev/null 2>&1') && 
          system('npx tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify')
      css_success = true
    # Method 3: Try running tailwindcss from node_modules/.bin
    elsif File.exist?('./node_modules/.bin/tailwindcss') &&
          system('./node_modules/.bin/tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify')
      css_success = true
    end
    
    raise('Failed to compile CSS assets <=== please investigate.') unless css_success
    puts 'CSS assets compiled successfully!'

    puts 'Compiling JavaScript assets for tests...'
    js_success = system('yarn build') || 
                 system('npm run build') ||
                 system('node esbuild.config.js')
    
    raise('Failed to compile JavaScript assets') unless js_success
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
