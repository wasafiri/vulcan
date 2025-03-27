# frozen_string_literal: true

# This initializer sets up Single Table Inheritance (STI) type mapping
# to allow the Admin module to coexist with the Users::Admin class
# for STI purposes

ActiveSupport.on_load(:active_record) do
  # Override how Rails maps "Admin" type strings to actual classes
  # This solves the problem where we need Admin to be both a module (for namespacing)
  # and a class (for STI)
  class ActiveRecord::Base
    class << self
      # Store the original find_sti_class method
      alias_method :original_find_sti_class, :find_sti_class
      
      # Override the find_sti_class method to handle our special cases
      def find_sti_class(type_name)
        if type_name == "Admin" && self <= User
          # Return the Users::Admin class for STI when the type is "Admin"
          Users::Admin
        else
          # For all other types, use the default behavior
          original_find_sti_class(type_name)
        end
      end
    end
  end
end
