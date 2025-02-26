class ContentTypeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value.attached?

    if options[:in].is_a?(String)
      content_types = [ options[:in] ]
    else
      content_types = options[:in] || []
    end

    unless content_types.include?(value.content_type)
      record.errors.add(attribute, options[:message] || "has an invalid content type")
    end
  end
end
