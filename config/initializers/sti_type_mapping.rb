# frozen_string_literal: true

# This initializer sets up Single Table Inheritance (STI) type mapping
# using Rails conventions for namespaced STI classes.
# This handles both reading types from the database and writing types to the database.

# Define the module outside the block to avoid constant definition in a block
# module NamespacedStiTypeName
#   def computed_type(value = self.class.name)
#     if value.start_with?('Users::')
#       # Strip the namespace when storing in the database
#       value.demodulize
#     else
#       super
#     end
#   end
# end

ActiveSupport.on_load(:active_record) do
  # Step 1: Override how Rails resolves the class from a database type string
  ActiveRecord::Base.singleton_class.class_eval do
    alias_method :original_sti_name_to_class, :sti_name_to_class if method_defined?(:sti_name_to_class)

    private

    # Override the Rails STI class resolver to handle our namespaced classes
    def sti_name_to_class(type_name)
      return original_sti_name_to_class(type_name) unless type_name.is_a?(String)

      # Special handling for User STI types
      if type_name.exclude?('::') &&
         (name == 'User' || ancestors.map(&:name).include?('User'))
        # For User STI types, try looking in the Users namespace first
        begin
          "Users::#{type_name}".constantize
        rescue NameError
          # If that fails, try looking for a top-level constant with the same name
          begin
            type_name.constantize
          rescue NameError
            # Fall back to original behavior if neither exists
            original_sti_name_to_class(type_name)
          end
        end
      else
        original_sti_name_to_class(type_name)
      end
    end
  end
end

# Step 2: Apply the module to User when it's available
# Note: We're no longer trying to define constants here, since that's now
# handled by the individual bridge files in app/models/
# ActiveSupport.on_load(:active_record) do
#   # Try to apply the module early if User is already loaded
#   User.prepend(NamespacedStiTypeName) if defined?(User) && !User.included_modules.include?(NamespacedStiTypeName)

#   # But also hook into after_initialize in case User wasn't loaded yet
#   ActiveSupport.on_load(:after_initialize) do
#     User.prepend(NamespacedStiTypeName) if defined?(User) && !User.included_modules.include?(NamespacedStiTypeName)
#   end
# end
