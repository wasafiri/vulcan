# frozen_string_literal: true

namespace :test do
  desc 'Compile assets for testing'
  task compile_assets: :environment do
    puts 'Compiling CSS assets for tests...'

    # Ensure dependencies are installed first
    unless Dir.exist?('./node_modules') && File.exist?('./node_modules/.bin/tailwindcss')
      puts 'Installing Node.js dependencies...'
      if system('which yarn > /dev/null 2>&1')
        system('yarn install') || raise('Failed to install dependencies with yarn')
      elsif system('which npm > /dev/null 2>&1')
        system('npm install') || raise('Failed to install dependencies with npm')
      else
        raise('Neither yarn nor npm found')
      end
    end

    # Now try to compile CSS
    css_success = system('yarn build:css') ||
                  system('npx tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify') ||
                  system('./node_modules/.bin/tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify') ||
                  system('node ./node_modules/tailwindcss/lib/cli.js -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css --minify')

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
