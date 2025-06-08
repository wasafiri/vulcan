# frozen_string_literal: true

module ParamCasting
  extend ActiveSupport::Concern

  # Standard boolean fields that need casting across the application
  BOOLEAN_FIELDS = %w[
    maryland_resident
    terms_accepted
    information_verified
    medical_release_authorized
    self_certify_disability
    hearing_disability
    vision_disability
    speech_disability
    mobility_disability
    cognition_disability
    use_guardian_email
    use_guardian_phone
    use_guardian_address
  ].freeze

  # Application-specific boolean fields (found in application params)
  APPLICATION_BOOLEAN_FIELDS = %w[
    maryland_resident
    terms_accepted
    information_verified
    medical_release_authorized
    self_certify_disability
  ].freeze

  # User disability fields (found in various nested structures)
  USER_DISABILITY_FIELDS = %w[
    hearing_disability
    vision_disability
    speech_disability
    mobility_disability
    cognition_disability
  ].freeze

  # Contact strategy checkboxes (specific to paper applications)
  STRATEGY_CHECKBOX_FIELDS = %w[
    use_guardian_email
    use_guardian_phone
    use_guardian_address
  ].freeze

  # Cast boolean values in the standard application params structure
  # This handles the most common case: params[:application] with boolean fields
  def cast_boolean_params
    return unless params[:application]

    cast_boolean_for(params[:application], APPLICATION_BOOLEAN_FIELDS + USER_DISABILITY_FIELDS)
  end

  # Cast boolean values in complex nested parameter structures
  # This handles the paper applications controller's more complex parameter structure
  def cast_complex_boolean_params
    # Cast for application attributes
    if params[:application].present?
      cast_boolean_for(params[:application], APPLICATION_BOOLEAN_FIELDS + USER_DISABILITY_FIELDS)
    end

    # Cast for disability attributes within nested structures
    cast_boolean_for(params[:applicant_attributes], USER_DISABILITY_FIELDS) if params[:applicant_attributes].present?
    cast_boolean_for(params[:guardian_attributes], USER_DISABILITY_FIELDS) if params[:guardian_attributes].present?
    cast_boolean_for(params[:constituent], USER_DISABILITY_FIELDS) if params[:constituent].present?

    # Cast contact strategy checkboxes
    STRATEGY_CHECKBOX_FIELDS.each do |checkbox_param|
      params[checkbox_param] = to_boolean(params[checkbox_param]) if params[checkbox_param].present?
    end
  end

  # Safely cast a single value to boolean
  # @param value [Object] The value to cast
  # @return [Boolean] The safely cast boolean value
  def to_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  # Legacy method name for backward compatibility
  alias safe_boolean_cast to_boolean

  private

  # Cast boolean values for specific fields within a hash
  # @param hash [ActionController::Parameters, Hash] The parameter hash to modify
  # @param fields [Array<String>] The field names to cast
  def cast_boolean_for(hash, fields)
    return unless hash.is_a?(ActionController::Parameters) || hash.is_a?(Hash)

    fields.each do |field|
      field_sym = field.to_sym
      next unless hash.key?(field_sym)

      value = hash[field_sym]
      # Handle array workaround for hidden checkbox fields (Rails pattern)
      value = value.last if value.is_a?(Array) && value.size == 2 && value.first.blank?
      hash[field_sym] = to_boolean(value)
    end
  end
end 