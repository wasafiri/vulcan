# frozen_string_literal: true

# Concern that provides a method for safely assigning instance variables
# by sanitizing variable names to ensure they're valid Ruby identifiers
module SafeInstanceVariables
  extend ActiveSupport::Concern

  # Safely assigns a value to an instance variable after sanitizing the key
  # @param key [String, Symbol] The variable name, without the '@' prefix
  # @param value [Object] The value to assign
  def safe_assign(key, value)
    # Strip leading @ if present and sanitize key to ensure valid Ruby variable name
    sanitized_key = key.to_s.sub(/\A@/, '').gsub(/[^0-9a-zA-Z_]/, '_')
    instance_variable_set("@#{sanitized_key}", value)
  end

  # Safely assigns multiple instance variables from a hash
  # @param hash [Hash] Hash where keys are instance variable names and values are the values to assign
  def safe_assign_all(hash)
    hash.each do |key, value|
      safe_assign(key, value)
    end
  end
end
