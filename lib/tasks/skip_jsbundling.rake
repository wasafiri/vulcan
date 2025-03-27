# frozen_string_literal: true

if Rails.env.test?
  if Rake::Task.task_defined?('javascript:install')
    Rake::Task['javascript:install'].clear
    Rake::Task.define_task('javascript:install') do
      puts 'Skipping javascript:install in test environment'
    end
  end

  if Rake::Task.task_defined?('javascript:build')
    Rake::Task['javascript:build'].clear
    Rake::Task.define_task('javascript:build') do
      puts 'Skipping javascript:build in test environment'
    end
  end

  if Rake::Task.task_defined?('test:prepare')
    Rake::Task['test:prepare'].clear_prerequisites
    Rake::Task.define_task('test:prepare') do
      puts 'Skipping test:prepare prerequisites in test environment'
    end
  end
end
