# frozen_string_literal: true

require 'fileutils'
require 'net/http'
require 'uri'
require 'zip'
require_relative 'version'
require_relative 'paths'

module TestBrowsers
  class Downloader
    BASE_URL = "https://storage.googleapis.com/chrome-for-testing-public"

    # Ensure both Chrome and ChromeDriver are downloaded and extracted
    def self.ensure_binaries!
      Paths.ensure_directories!
      return if binaries_exist?

      download_chrome
      download_chromedriver
      
      # Verify binaries exist and are executable
      make_executable(Paths.chrome_binary)
      make_executable(Paths.chromedriver_binary)
      
      # Verify binaries are available
      unless binaries_exist?
        raise "Failed to download Chrome for Testing binaries. Check paths and permissions."
      end
      
      puts "Successfully downloaded Chrome for Testing v#{Version::CHROME_VERSION}"
    end

    # Check if binaries already exist and are valid
    def self.binaries_exist?
      chrome_exists = File.exist?(Paths.chrome_binary) && File.executable?(Paths.chrome_binary)
      driver_exists = File.exist?(Paths.chromedriver_binary) && File.executable?(Paths.chromedriver_binary)
      
      chrome_exists && driver_exists
    end

    # Download Chrome browser binary
    def self.download_chrome
      platform = Version::chrome_platform
      url = "#{BASE_URL}/#{Version::CHROME_VERSION}/#{platform}/chrome-#{platform}.zip"
      
      puts "Downloading Chrome for Testing (#{Version::CHROME_VERSION})..."
      download_file(url, Paths.chrome_zip)
      extract_zip(Paths.chrome_zip, Paths.chrome_dir)
      FileUtils.rm_f(Paths.chrome_zip) # Clean up zip file
    end

    # Download matching ChromeDriver binary
    def self.download_chromedriver
      platform = Version::chrome_platform
      url = "#{BASE_URL}/#{Version::CHROME_VERSION}/#{platform}/chromedriver-#{platform}.zip"
      
      puts "Downloading ChromeDriver (#{Version::CHROME_VERSION})..."
      download_file(url, Paths.chromedriver_zip)
      extract_zip(Paths.chromedriver_zip, Paths.chromedriver_dir)
      FileUtils.rm_f(Paths.chromedriver_zip) # Clean up zip file
    end

    private

    # Helper to download a file from URL to path
    def self.download_file(url, path)
      uri = URI(url)
      
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri)
        
        http.request(request) do |response|
          case response
          when Net::HTTPSuccess
            total_size = response['Content-Length'].to_i
            downloaded_size = 0
            
            File.open(path, 'wb') do |file|
              response.read_body do |chunk|
                file.write(chunk)
                downloaded_size += chunk.size
                print "\rDownloading: #{(downloaded_size.to_f / total_size * 100).round(1)}% " if total_size > 0
              end
            end
            puts "\rDownload complete!                                           "
          else
            raise "Error downloading from #{url}: #{response.code} #{response.message}"
          end
        end
      end
    end

    # Extract a zip file to a directory
    def self.extract_zip(zip_path, extract_dir)
      puts "Extracting #{zip_path} to #{extract_dir}..."
      
      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |entry|
          entry_path = File.join(extract_dir, entry.name)
          FileUtils.mkdir_p(File.dirname(entry_path))
          
          # Skip if directory
          next if entry.directory?
          
          # Extract the file
          entry.extract(entry_path) { true } # Overwrite
        end
      end
      
      puts "Extraction complete!"
    end

    # Make a file executable
    def self.make_executable(path)
      return unless File.exist?(path)
      File.chmod(0755, path) # rwxr-xr-x permissions
    end
  end
end
