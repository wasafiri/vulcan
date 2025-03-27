# frozen_string_literal: true

class ContentTypeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value.attached?

    content_types = if options[:in].is_a?(String)
                      [options[:in]]
                    else
                      options[:in] || []
                    end

    return if content_types.include?(value.content_type)

    record.errors.add(attribute, options[:message] || 'has an invalid content type')
  end
end
