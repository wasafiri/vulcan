class SizeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value.attached?

    if options[:less_than].present?
      if value.byte_size >= options[:less_than]
        record.errors.add(attribute, options[:message] || "is too large")
      end
    end
  end
end
