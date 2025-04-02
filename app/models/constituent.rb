# frozen_string_literal: true

# This file acts as a bridge between the Constituent constant needed for backward compatibility
# and the Users::Constituent class needed for Single Table Inheritance

# Include the actual implementation
require_dependency 'users/constituent'

# Define Constituent class for STI backward compatibility
# This helps Rails find the class when loading from the database
Constituent = Users::Constituent unless defined?(Constituent)
