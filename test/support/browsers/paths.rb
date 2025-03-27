# frozen_string_literal: true

require_relative 'version'

module TestBrowsers
  module Paths
    # Base directory for browser binaries
    def self.root
      @root ||= Rails.root.join('tmp', 'test_browsers')
    end

    # Create directory if it doesn't exist
    def self.ensure_directories!
      FileUtils.mkdir_p(root) unless Dir.exist?(root)
      FileUtils.mkdir_p(chrome_dir) unless Dir.exist?(chrome_dir)
      FileUtils.mkdir_p(chromedriver_dir) unless Dir.exist?(chromedriver_dir)
    end

    # Chrome binary directory
    def self.chrome_dir
      root.join("chrome-#{Version::CHROME_VERSION}")
    end

    # Chrome binary path
    def self.chrome_binary
      return @chrome_binary if defined?(@chrome_binary)

      platform = Version.chrome_platform

      @chrome_binary = if platform.start_with?('mac')
                         chrome_dir.join("chrome-#{platform}",
                                         'Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing')
                       elsif platform.start_with?('linux')
                         chrome_dir.join("chrome-#{platform}", 'chrome')
                       else # Windows
                         chrome_dir.join("chrome-#{platform}", 'chrome.exe')
                       end
    end

    # ChromeDriver directory
    def self.chromedriver_dir
      root.join("chromedriver-#{Version::CHROME_VERSION}")
    end

    # ChromeDriver binary path
    def self.chromedriver_binary
      return @chromedriver_binary if defined?(@chromedriver_binary)

      platform = Version.chrome_platform
      filename = "chromedriver#{Version.binary_suffix}"

      @chromedriver_binary = chromedriver_dir.join("chromedriver-#{platform}", filename)
    end

    # Chrome download ZIP path (temporary)
    def self.chrome_zip
      root.join("chrome-#{Version::CHROME_VERSION}-#{Version.chrome_platform}.zip")
    end

    # ChromeDriver download ZIP path (temporary)
    def self.chromedriver_zip
      root.join("chromedriver-#{Version::CHROME_VERSION}-#{Version.chrome_platform}.zip")
    end
  end
end
