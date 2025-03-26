# lib/tasks/check_email_letter_consistency.rake
namespace :letters do
  desc 'Check for emails without matching print queue letters'
  task check_email_letter_consistency: :environment do
    puts "Checking for email templates without matching letter templates..."
    
    # Get all template paths for email templates from application_notifications_mailer
    email_template_dir = Rails.root.join('app/views/application_notifications_mailer')
    email_templates = Dir.glob("#{email_template_dir}/*.{html,text}.erb").map do |path|
      File.basename(path).gsub(/(\.html|\.text)\.erb$/, '')
    end.uniq
    
    # Get all letter templates
    letter_template_dir = Rails.root.join('app/views/letters')
    letter_templates = Dir.glob("#{letter_template_dir}/*.html.erb").map do |path|
      File.basename(path).gsub(/\.html\.erb$/, '')
    end
    
    # Find email templates without matching letter templates
    missing_letters = email_templates.select { |template| !letter_templates.include?(template) }
    
    if missing_letters.any?
      puts "\n⚠️ Found #{missing_letters.count} email templates without matching letter templates:"
      missing_letters.each do |template|
        puts "  - #{template}"
      end
      puts "\nConsider creating letter templates for these emails to ensure customers without email access receive printed communications."
    else
      puts "✓ All email templates have matching letter templates."
    end
    
    # Check for mailer methods that might trigger emails
    mailer_classes = [
      ApplicationNotificationsMailer,
      EvaluatorMailer, 
      TrainingSessionNotificationsMailer,
      UserMailer,
      VendorNotificationsMailer,
      VoucherNotificationsMailer
    ]
    
    puts "\nChecking for mailer methods without letter generation..."
    
    letter_types = PrintQueueItem.pluck(:letter_type).uniq
    missing_letter_methods = []
    
    mailer_classes.each do |mailer_class|
      mailer_methods = mailer_class.instance_methods(false)
      
      mailer_methods.each do |method|
        method_name = method.to_s
        
        # Skip methods that don't send emails
        next if method_name.start_with?('_') || method_name == 'mail'
        
        # Check if there's a corresponding letter type
        unless letter_types.include?(method_name)
          missing_letter_methods << "#{mailer_class.name}##{method_name}"
        end
      end
    end
    
    if missing_letter_methods.any?
      puts "\n⚠️ Found #{missing_letter_methods.count} mailer methods without corresponding letter types:"
      missing_letter_methods.each do |method|
        puts "  - #{method}"
      end
      puts "\nConsider adding letter generation for these methods in the LetterGeneratorService."
    else
      puts "✓ All mailer methods have corresponding letter types."
    end
    
    # Check letter generation in services
    puts "\nChecking LetterGeneratorService for comprehensive coverage..."
    
    letter_generator_path = Rails.root.join('app/services/letters/letter_generator_service.rb')
    if File.exist?(letter_generator_path)
      letter_generator_source = File.read(letter_generator_path)
      
      mailer_methods_not_in_generator = []
      
      mailer_classes.each do |mailer_class|
        mailer_methods = mailer_class.instance_methods(false)
        
        mailer_methods.each do |method|
          method_name = method.to_s
          
          # Skip methods that don't send emails
          next if method_name.start_with?('_') || method_name == 'mail'
          
          # Check if method is mentioned in the letter generator
          unless letter_generator_source.include?(method_name)
            mailer_methods_not_in_generator << "#{mailer_class.name}##{method_name}"
          end
        end
      end
      
      if mailer_methods_not_in_generator.any?
        puts "\n⚠️ Found #{mailer_methods_not_in_generator.count} mailer methods not handled in LetterGeneratorService:"
        mailer_methods_not_in_generator.each do |method|
          puts "  - #{method}"
        end
        puts "\nConsider updating LetterGeneratorService to handle these email types."
      else
        puts "✓ LetterGeneratorService appears to handle all mailer methods."
      end
    else
      puts "❌ Could not find LetterGeneratorService at expected path."
    end
  end
end
