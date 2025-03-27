# frozen_string_literal: true

# This initializer sets up Single Table Inheritance (STI) type mapping
# to allow the Admin module to coexist with the Users::Admin class
# for STI purposes

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.singleton_class.class_eval do
    alias_method original_find_sti_class find_sti_class

    def find_sti_class(type_name)
      if type_name == "Admin" && self <= User
        Users::Admin
      else
        original_find_sti_class(type_name)
      end
    end
  end
end
