# frozen_string_literal: true

# --- TEMPORARY DIAGNOSTIC STEP ---
# Goal: Prevent assets:clean from running after assets:precompile during build
# to see if it's incorrectly removing the .propshaft_manifest.json file.
# If this fixes the runtime error, the root cause is likely within assets:clean.
# If not, the root cause is likely within assets:precompile's manifest generation.
# This file should ideally be removed after diagnosis.

# Clear existing task definition to avoid invoking assets:clean implicitly
Rake::Task['assets:precompile'].clear

# Redefine assets:precompile without the assets:clean dependency
# Based on the default task definition but omitting the clean step invocation
namespace :assets do
  desc 'Compile all the assets named in config.assets.precompile (without cleaning)'
  task precompile: :environment do
    Rails.logger.info 'Running custom assets:precompile (skipping assets:clean)'
    config = Rails.application.config
    config.assets.compile = true # Ensure compilation is enabled for the task
    Propshaft::Compiler.new(config.assets).compile # This includes manifest generation
    Rake::Task['css:build'].invoke if Rake::Task.task_defined?('css:build')
    Rake::Task['javascript:build'].invoke if Rake::Task.task_defined?('javascript:build')
    Rails.logger.info 'Custom assets:precompile finished.'
  end
end
