# frozen_string_literal: true

require 'mocha/minitest'

# Provides a standardized way to mock ActiveStorage attachments for tests,
# ensuring all necessary methods are stubbed to prevent common errors like
# "unexpected invocation: #<Mock:0x...>.byte_size()".
module AttachmentTestHelper
  # Wrap a block in a fully mocked ActiveStorage service.
  #
  # This allows service tests to run without actual file operations
  # while maintaining the expected interface for code using ActiveStorage.
  #
  # @yield Block to execute with mocked attachments
  def with_mocked_attachments(&)
    mock_service = build_mock_service
    ActiveStorage::Blob.stub(:service, mock_service, &)
  end

  # Build a mock ActiveStorage service with all required methods
  # @return [Object] A mock service object with the ActiveStorage interface
  def build_mock_service
    Class.new do
      def upload(key, _io, _checksum: nil, **)
        key # return the key so callers get what they expect
      end

      def download(*) = +'fake-content'
      def url(key, **) = "http://example.com/#{key}"
      def delete(*) = true
      def exist?(*) = true

      # Add other methods that might be called
      def open(*)
        StringIO.new('fake-content')
      end

      def url_for(key, _expires_in: nil, disposition: nil, filename: nil, **)
        "http://example.com/#{key}?disposition=#{disposition}&filename=#{filename}"
      end
    end.new
  end

  # Creates a comprehensive mock for an ActiveStorage::Attached::One object
  # and its associated ActiveStorage::Blob.
  #
  # @param filename [String] The desired filename for the mock blob.
  # @param content_type [String] The desired content type for the mock blob.
  # @param byte_size [Integer] The desired byte size for the mock blob.
  # @param created_at [Time] The desired creation timestamp for the mock blob.
  # @param attached [Boolean] Whether the mock attachment should report as attached.
  # @return [Mocha::Mock] A mock object simulating an ActiveStorage::Attached::One instance.
  def mock_attached_file(filename: 'test.pdf', content_type: 'application/pdf', byte_size: 100.kilobytes, created_at: Time.current,
                         attached: true)
    # Create a proper ActiveStorage::Filename object instead of mocking it
    filename_obj = ActiveStorage::Filename.new(filename)

    # Mock the Blob
    blob_mock = mock("ActiveStorage::Blob #{filename}")
    blob_mock.stubs(:filename).returns(filename_obj)
    blob_mock.stubs(:content_type).returns(content_type)
    blob_mock.stubs(:byte_size).returns(byte_size)
    blob_mock.stubs(:created_at).returns(created_at)
    # Add other common blob methods if needed (e.g., metadata, service_url)
    blob_mock.stubs(:download).returns("Mock content for #{filename}")
    blob_mock.stubs(:url).returns("http://test.host/mock_url_for_#{filename}")
    blob_mock.stubs(:key).returns("mock_key_for_#{filename}")

    # Mock the Attachment
    attachment_mock = mock("ActiveStorage::Attached::One #{filename}")
    attachment_mock.stubs(:attached?).returns(attached)

    if attached
      attachment_mock.stubs(:blob).returns(blob_mock)
      # Delegate common methods to the blob mock for consistency
      attachment_mock.stubs(:filename).returns(blob_mock.filename)
      attachment_mock.stubs(:content_type).returns(blob_mock.content_type)
      attachment_mock.stubs(:byte_size).returns(blob_mock.byte_size)
      attachment_mock.stubs(:created_at).returns(blob_mock.created_at)
      attachment_mock.stubs(:download).returns(blob_mock.download)
      attachment_mock.stubs(:url).returns(blob_mock.url)
      attachment_mock.stubs(:key).returns(blob_mock.key)
      # Add other common attachment methods if needed (e.g., purge, attach)
      attachment_mock.stubs(:purge)
      attachment_mock.stubs(:purge_later)
      attachment_mock.stubs(:attach)
    else
      # If not attached, blob should likely be nil or raise an error
      attachment_mock.stubs(:blob).raises(ActiveStorage::FileNotFoundError) # Or returns nil depending on expected behavior
      # Stub other methods to return nil or raise errors as appropriate for an unattached file
      attachment_mock.stubs(:filename).returns(nil)
      attachment_mock.stubs(:content_type).returns(nil)
      attachment_mock.stubs(:byte_size).returns(nil)
      attachment_mock.stubs(:created_at).returns(nil)
      attachment_mock.stubs(:download).raises(ActiveStorage::FileNotFoundError)
      attachment_mock.stubs(:url).returns(nil)
      attachment_mock.stubs(:key).returns(nil)
    end

    attachment_mock
  end
end
