# frozen_string_literal: true

# This initializer sets up Single Table Inheritance (STI) type mapping
# using Rails conventions for namespaced STI classes.
# This handles both reading types from the database and writing types to the database.

require_relative '../../app/models/application_record'

# Define the module outside the block to avoid constant definition in a block
module NamespacedStiTypeName
  def computed_type(value = self.class.name)
    if value.start_with?('Users::')
      # Strip the namespace when storing in the database
      value.demodulize
    else
      super
    end
  end
end

ActiveSupport.on_load(:active_record) do
  # Step 1: Override how Rails resolves the class from a database type string
  ActiveRecord::Base.singleton_class.class_eval do
    alias_method :original_sti_name_to_class, :sti_name_to_class if method_defined?(:sti_name_to_class)

    private

    # Override the Rails STI class resolver to handle our namespaced classes
    def sti_name_to_class(type_name)
      if self.name == 'User' || (self.ancestors.map(&:name).include?('User') && type_name.exclude?('::'))
        # For User STI types, try looking in the Users namespace first
        begin
          "Users::#{type_name}".constantize
        rescue NameError
          # Fall back to original behavior if class doesn't exist in Users namespace
          original_sti_name_to_class(type_name)
        end
      else
        original_sti_name_to_class(type_name)
      end
    end
  end
end

# Step 2: We'll add this in a separate hook to ensure User is loaded
ActiveSupport.on_load(:user) do
  User.prepend(NamespacedStiTypeName)
end

# Make sure we define the hook for the User model
ActiveSupport.run_load_hooks(:user, User) rescue nil
