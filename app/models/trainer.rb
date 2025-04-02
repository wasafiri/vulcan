# frozen_string_literal: true

# This file acts as a bridge between the Trainer constant needed for backward compatibility
# and the Users::Trainer class needed for Single Table Inheritance

# Include the actual implementation
require_dependency 'users/trainer'

# Define Trainer class for STI backward compatibility
# This helps Rails find the class when loading from the database
Trainer = Users::Trainer unless defined?(Trainer)
