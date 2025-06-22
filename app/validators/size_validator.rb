# frozen_string_literal: true

class SizeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return unless value.attached?

    return if options[:less_than].blank?
    return unless value.byte_size >= options[:less_than]

    record.errors.add(attribute, options[:message] || 'is too large')
  end
end
