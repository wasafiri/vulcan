# frozen_string_literal: true

# This file acts as a bridge between the Vendor constant needed for backward compatibility
# and the Users::Vendor class needed for Single Table Inheritance

# Include the actual implementation
require_dependency 'users/vendor'

# Define Vendor class for STI backward compatibility
# This helps Rails find the class when loading from the database
Vendor = Users::Vendor unless defined?(Vendor)
