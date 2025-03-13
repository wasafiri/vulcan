# frozen_string_literal: true

# Helper module for managing Chrome for Testing processes
module ChromeProcessManager
  # Constants for process patterns to ensure we don't affect regular Chrome
  CHROME_FOR_TESTING_PATTERN = 'Google Chrome for Testing'
  CHROMEDRIVER_TESTING_PATTERN = 'chromedriver.*for.*testing'
  
  # Verify regular Chrome wasn't affected
  def self.verify_regular_chrome_preserved?
    if RUBY_PLATFORM =~ /darwin/ || RUBY_PLATFORM =~ /linux/
      # Use regex that matches "Google Chrome" but not "Google Chrome for Testing"
      regular_chrome = `pgrep -f "Google Chrome$" | wc -l`.strip.to_i
      regular_chrome.positive?
    elsif RUBY_PLATFORM =~ /mswin|mingw/
      # Windows version
      regular_chrome = `tasklist | find /i "chrome.exe" | find /v "for Testing" | measure-object -line | select-object -expandproperty Lines`.strip.to_i
      regular_chrome.positive?
    else
      # Can't determine on unknown platform
      true
    end
  end
  
  # Gracefully shutdown a process by pattern
  def self.graceful_shutdown(process_pattern)
    if RUBY_PLATFORM =~ /darwin/ || RUBY_PLATFORM =~ /linux/
      # Try SIGTERM first
      system("pkill -TERM -f '#{process_pattern}' > /dev/null 2>&1 || true")
      
      # Wait for grace period
      sleep the_grace_period
      
      # Check if process still exists
      count = `pgrep -f '#{process_pattern}' | wc -l`.strip.to_i
      if count > 0
        puts "Process still running after SIGTERM, using force kill for testing processes..."
        system("pkill -9 -f '#{process_pattern}' > /dev/null 2>&1 || true")
      end
    elsif RUBY_PLATFORM =~ /mswin|mingw/
      # Windows version - no SIGTERM equivalent, just use taskkill
      process_name = process_pattern.gsub(/\..*$/, '.exe')
      system("taskkill //IM \"#{process_name}\" > /dev/null 2>&1 || true") 
      
      sleep the_grace_period
      
      # Force if still running
      system("taskkill //F //IM \"#{process_name}\" > /dev/null 2>&1 || true")
    end
  end
  
  # Grace period in seconds - can be overridden with environment variable
  def self.the_grace_period
    (ENV['CHROME_GRACE_PERIOD'] || 2).to_i
  end
  
  # Gracefully clean up Chrome for Testing processes
  # Does not touch regular Chrome browser processes
  def self.cleanup_test_processes
    # Check for regular Chrome
    had_regular_chrome = verify_regular_chrome_preserved?
    
    # Chrome for Testing - extremely specific pattern
    graceful_shutdown(CHROME_FOR_TESTING_PATTERN)
    
    # ChromeDriver used for testing - more specific pattern
    graceful_shutdown(CHROMEDRIVER_TESTING_PATTERN)
    
    # Verify regular Chrome wasn't affected if it existed before
    if had_regular_chrome && verify_regular_chrome_preserved?
      puts "✓ Regular Chrome browser preserved during test process cleanup"
    elsif had_regular_chrome
      puts "! Warning: Regular Chrome browser may have been affected - please check"
    end
  end
  
  # Check if there are any orphaned Chrome for Testing processes
  def self.orphaned_processes?
    chrome_count = 0
    chromedriver_count = 0
    
    if RUBY_PLATFORM =~ /darwin/ || RUBY_PLATFORM =~ /linux/
      # Unix-like systems - use precise patterns
      chrome_count = `pgrep -f '#{CHROME_FOR_TESTING_PATTERN}' | wc -l`.strip.to_i
      chromedriver_count = `pgrep -f '#{CHROMEDRIVER_TESTING_PATTERN}' | wc -l`.strip.to_i
    elsif RUBY_PLATFORM =~ /mswin|mingw/
      # Windows - more limited matching
      chrome_count = `tasklist | find /i "Google Chrome for Testing.exe" | measure-object -line | select-object -expandproperty Lines`.strip.to_i
      chromedriver_count = `tasklist | find /i "chromedriver.exe" | measure-object -line | select-object -expandproperty Lines`.strip.to_i
    end
    
    chrome_count.positive? || chromedriver_count.positive?
  end
end
