# frozen_string_literal: true

require 'test_helper'

class MedicalProviderMailerTest < ActionMailer::TestCase
  setup do
    @constituent = create(:constituent)
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
    assert_match(/Disability Certification Form Request for #{@constituent.full_name}/, email.subject)

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'certification'
    assert_includes html_part.body.to_s, @constituent.full_name

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'certification'
    assert_includes text_part.body.to_s, @constituent.full_name
  end
end
