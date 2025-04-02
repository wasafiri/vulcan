# frozen_string_literal: true

# This file acts as a bridge between the Administrator constant needed for backward compatibility
# and the Users::Administrator class needed for Single Table Inheritance

# Include the actual implementation
require_dependency 'users/administrator'

# Define Administrator class for STI backward compatibility
# This helps Rails find the class when loading from the database
Administrator = Users::Administrator unless defined?(Administrator)
