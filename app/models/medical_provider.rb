# frozen_string_literal: true

# This file acts as a bridge between the MedicalProvider constant needed for backward compatibility
# and the Users::MedicalProvider class needed for Single Table Inheritance

# Include the actual implementation
require_dependency 'users/medical_provider'

# Define MedicalProvider class for STI backward compatibility
# This helps Rails find the class when loading from the database
MedicalProvider = Users::MedicalProvider unless defined?(MedicalProvider)
