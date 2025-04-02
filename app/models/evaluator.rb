# frozen_string_literal: true

# This file acts as a bridge between the Evaluator constant needed for backward compatibility
# and the Users::Evaluator class needed for Single Table Inheritance

# Include the actual implementation
require_dependency 'users/evaluator'

# Define Evaluator class for STI backward compatibility
# This helps Rails find the class when loading from the database
Evaluator = Users::Evaluator unless defined?(Evaluator)
