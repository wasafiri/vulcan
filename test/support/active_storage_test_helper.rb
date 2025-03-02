# frozen_string_literal: true

# Helper methods for testing Active Storage attachments
module ActiveStorageTestHelper
  # Mock the filename for an Active Storage attachment
  # This is useful for testing views that display attachment filenames
  # @param attachment [ActiveStorage::Attached::One] The attachment to mock
  # @param filename [String] The filename to use
  # @return [ActiveStorage::Attached::One] The mocked attachment
  def mock_attachment_filename(attachment, filename)
    # Create a mock blob with the specified filename
    blob = attachment.blob
    allow(blob).to receive(:filename).and_return(filename)
    allow(attachment).to receive(:blob).and_return(blob)
    attachment
  end
end
