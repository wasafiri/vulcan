# frozen_string_literal: true

# This file acts as a bridge between the Vendor constant needed for backward compatibility
# and the Users::Vendor class needed for Single Table Inheritance

# Include the actual implementation
require_dependency 'users/vendor'

# Define a proper Vendor class for STI that maintains compatibility with existing tests
class Vendor < Users::Vendor
  # Don't override the database type column - keep it as is to maintain compatibility
  # Virtual attribute for handling terms acceptance.
  # When the form sends a "terms_accepted" value (e.g., "1" for checked),
  # this getter returns true if "terms_accepted_at" is present.
  def terms_accepted
    !!terms_accepted_at
  end

  # The setter converts the submitted value into a timestamp.
  # If the value is truthy (checked), it sets terms_accepted_at to the current time;
  # otherwise, it clears the timestamp.
  def terms_accepted=(value)
    if ActiveModel::Type::Boolean.new.cast(value)
      self.terms_accepted_at ||= Time.current
    else
      self.terms_accepted_at = nil
    end
  end
end
