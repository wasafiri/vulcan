# frozen_string_literal: true

require 'test_helper'

class MedicalProviderMailerTest < ActionMailer::TestCase
  # Helper to create mock templates that performs interpolation
  def mock_template(subject_format, body_format)
    template = mock('email_template')
    # Stub render to accept keyword args and perform interpolation
    template.stubs(:render).with(any_parameters).returns do |**vars|
      rendered_subject = subject_format % vars
      rendered_body = body_format % vars
      [rendered_subject, rendered_body]
    end
    template
  end

  setup do
    # Stub specific EmailTemplate lookups for the methods under test
    # Use format strings for subject/body
    @mock_request_template_html = mock_template(
      'Mock Request Cert Subject for %<constituent_full_name>s',
      '<p>Mock Request Cert Body for %<constituent_full_name>s</p>'.html_safe # Mark as HTML safe
    )
    @mock_request_template_text = mock_template(
      'Mock Request Cert Subject for %<constituent_full_name>s',
      'Mock Request Cert Body for %<constituent_full_name>s'
    )
    EmailTemplate.stubs(:find_by!).with(name: 'medical_provider_request_certification', format: :html).returns(@mock_request_template_html)
    EmailTemplate.stubs(:find_by!).with(name: 'medical_provider_request_certification', format: :text).returns(@mock_request_template_text)

    # Add stubs for other templates if/when those tests are added/unskipped
    # @mock_rejected_template = ...
    # EmailTemplate.stubs(:find_by!).with(name: 'medical_provider_certification_rejected', ...).returns(@mock_rejected_template)
    # @mock_error_template = ...
    # EmailTemplate.stubs(:find_by!).with(name: 'medical_provider_certification_submission_error', ...).returns(@mock_error_template)

    @constituent = create(:constituent, :with_address_and_phone)
    @application = create(:application,
                          user: @constituent,
                          medical_provider_email: 'provider@example.com',
                          medical_provider_name: 'Dr. Smith')
  end

  test 'request_certification' do
    email = MedicalProviderMailer.request_certification(@application)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['info@mdmat.org'], email.from
    assert_equal [@application.medical_provider_email], email.to
    # Assert against the stubbed subject
    assert_equal "Mock Request Cert Subject for #{@constituent.full_name}", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    # Assert against the stubbed body
    assert_includes html_part.body.to_s, "Mock Request Cert Body for #{@constituent.full_name}"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    # Assert against the stubbed body
    assert_includes text_part.body.to_s, "Mock Request Cert Body for #{@constituent.full_name}"
  end

  test 'certification_rejected' do
    # Setup template mocks with different subject/body formats
    html_template = mock_template(
      'Certification Rejected: %<constituent_full_name>s',
      '<p>HTML Rejection Reason: %<rejection_reasons>s</p>'
    )
    text_template = mock_template(
      'Certification Rejected: %<constituent_full_name>s',
      'Text Rejection Reason: %<rejection_reasons>s'
    )

    EmailTemplate.stubs(:find_by!)
                 .with(name: 'medical_provider_certification_rejected', format: :html)
                 .returns(html_template)
    EmailTemplate.stubs(:find_by!)
                 .with(name: 'medical_provider_certification_rejected', format: :text)
                 .returns(text_template)

    # Create test data with rejection reasons
    rejection_reasons = ['Incomplete documentation', 'Expired license']
    email = MedicalProviderMailer.certification_rejected(
      @application,
      rejection_reasons.join(', '),
      create(:admin)
    )

    assert_emails 1 do
      email.deliver_later
    end

    # Verify email basics
    assert_equal ['info@mdmat.org'], email.from
    assert_equal [@application.medical_provider_email], email.to
    assert_equal "Certification Rejected: #{@constituent.full_name}", email.subject

    # Test both parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |p| p.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, "HTML Rejection Reason: #{rejection_reasons.join(', ')}"

    # Text part
    text_part = email.parts.find { |p| p.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, "Text Rejection Reason: #{rejection_reasons.join(', ')}"
  end

  test 'certification_submission_error' do
    # Setup template mocks
    html_template = mock_template(
      'Submission Error: %<medical_provider_email>s',
      '<p>Error: %<error_message>s</p>'
    )
    text_template = mock_template(
      'Submission Error: %<medical_provider_email>s',
      'Error: %<error_message>s'
    )

    EmailTemplate.stubs(:find_by!)
                 .with(name: 'medical_provider_certification_submission_error', format: :html)
                 .returns(html_template)
    EmailTemplate.stubs(:find_by!)
                 .with(name: 'medical_provider_certification_submission_error', format: :text)
                 .returns(text_template)

    # Test with application
    provider = create(:medical_provider, email: 'error_test@example.com')
    error_message = 'Invalid document format'
    email = MedicalProviderMailer.certification_submission_error(
      provider,
      @application,
      :invalid_format,
      error_message
    )

    assert_emails 1 do
      email.deliver_later
    end

    # Verify email details
    assert_equal ['info@mdmat.org'], email.from
    assert_equal [provider.email], email.to
    assert_equal "Submission Error: #{provider.email}", email.subject

    # Verify content
    html_part = email.parts.find { |p| p.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, "Error: #{error_message}"
    assert_includes html_part.body.to_s, @constituent.full_name

    text_part = email.parts.find { |p| p.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, "Error: #{error_message}"
    assert_includes text_part.body.to_s, @constituent.full_name
  end
end
