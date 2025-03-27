# frozen_string_literal: true

module TestBrowsers
  module Version
    # The stable Chrome for Testing version
    CHROME_VERSION = '134.0.6998.35'

    # Determine the platform-specific identifier for downloads
    def self.chrome_platform
      case RUBY_PLATFORM
      when /darwin/
        RUBY_PLATFORM.include?('arm64') ? 'mac-arm64' : 'mac-x64'
      when /linux/
        'linux64'
      when /mingw|mswin/
        'win64'
      else
        # Default to a common platform if we can't detect
        warn "Warning: Unable to determine platform from #{RUBY_PLATFORM}, defaulting to mac-x64"
        'mac-x64'
      end
    end

    # Get the platform-specific filename suffix
    def self.binary_suffix
      case RUBY_PLATFORM
      when /mingw|mswin/
        '.exe'
      else
        ''
      end
    end
  end
end
