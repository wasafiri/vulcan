# frozen_string_literal: true

require 'test_helper'

class ActiveStorageValidatableTest < ActiveSupport::TestCase
  # Create a simple test model that includes the concern
  class TestModel
    include ActiveModel::Model
    include ActiveModel::Attributes
    include ActiveModel::Validations
    include ActiveStorageValidatable

    attr_accessor :test_attachment

    def initialize
      @test_attachment = OpenStruct.new(attached?: false)
    end

    def attach_file(content_type:, size:)
      @test_attachment = OpenStruct.new(
        attached?: true,
        content_type: content_type,
        byte_size: size
      )
    end
  end

  test 'validates content type correctly' do
    model = TestModel.new

    # Test valid content type
    model.attach_file(content_type: 'application/pdf', size: 2.megabytes)
    model.send(:validate_attachment_content_type, model.test_attachment, :test_attachment)
    assert_empty model.errors[:test_attachment]

    # Test invalid content type
    model.errors.clear
    model.attach_file(content_type: 'application/exe', size: 2.megabytes)
    model.send(:validate_attachment_content_type, model.test_attachment, :test_attachment)
    assert_includes model.errors[:test_attachment], 'Invalid file type. Please upload a PDF or an image file (jpg, jpeg, png, tiff, bmp).'
  end

  test 'validates file size correctly' do
    model = TestModel.new

    # Test valid size
    model.attach_file(content_type: 'application/pdf', size: 2.megabytes)
    model.send(:validate_attachment_size, model.test_attachment, :test_attachment)
    assert_empty model.errors[:test_attachment]

    # Test file too large
    model.errors.clear
    model.attach_file(content_type: 'application/pdf', size: 10.megabytes)
    model.send(:validate_attachment_size, model.test_attachment, :test_attachment)
    assert_includes model.errors[:test_attachment], 'File is too large. Maximum size allowed is 5MB.'

    # Test file too small (only in non-test environments)
    unless Rails.env.test?
      model.errors.clear
      model.attach_file(content_type: 'application/pdf', size: 100.bytes)
      model.send(:validate_attachment_size, model.test_attachment, :test_attachment)
      assert_includes model.errors[:test_attachment], 'File is too small. Minimum size required is 1024 bytes.'
    end
  end

  test 'class method validates file params correctly' do
    # Test valid file
    valid_file = OpenStruct.new(
      blank?: false,
      content_type: 'application/pdf',
      size: 2.megabytes
    )
    errors = TestModel.validate_file_params(valid_file)
    assert_empty errors

    # Test invalid content type
    invalid_file = OpenStruct.new(
      blank?: false,
      content_type: 'application/exe',
      size: 2.megabytes
    )
    errors = TestModel.validate_file_params(invalid_file)
    assert_includes errors, 'Invalid file type. Please upload a PDF or an image file (jpg, jpeg, png, tiff, bmp).'

    # Test file too large
    large_file = OpenStruct.new(
      blank?: false,
      content_type: 'application/pdf',
      size: 10.megabytes
    )
    errors = TestModel.validate_file_params(large_file)
    assert_includes errors, 'File is too large. Maximum size allowed is 5MB.'

    # Test blank file
    errors = TestModel.validate_file_params(nil)
    assert_includes errors, 'Please select a file to upload.'
  end

  test 'provides JavaScript validation config' do
    config = TestModel.js_validation_config

    assert_equal ActiveStorageValidatable::ALLOWED_CONTENT_TYPES, config[:allowed_types]
    assert_equal ActiveStorageValidatable::MAX_FILE_SIZE, config[:max_size_bytes]
    assert_equal 5, config[:max_size_mb]
    assert config[:error_messages].is_a?(Hash)
    assert config[:error_messages][:invalid_type].present?
    assert config[:error_messages][:file_too_large].present?
  end
end
