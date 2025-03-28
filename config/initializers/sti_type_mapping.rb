# frozen_string_literal: true

# This initializer sets up Single Table Inheritance (STI) type mapping
# to allow the Admin module to coexist with the Users::Admin class
# for STI purposes

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Base.singleton_class.class_eval do
    alias_method :original_find_sti_class, :find_sti_class

    def find_sti_class(type_name)
      if type_name == "Admin" && self <= User
        Users::Admin
      else
        original_find_sti_class(type_name)
      end
    end
  end
  
  # Also patch ActiveRecord::FixtureSet::TableRow to resolve Admin => Users::Admin
  # This is needed specifically for fixture loading when resolving enums
  ActiveRecord::FixtureSet::TableRow.class_eval do
    alias_method :original_resolve_enums, :resolve_enums
    
    def resolve_enums
      # Handle the Admin => Users::Admin case specifically for fixtures
      if @fixture && @fixture['type'] == 'Admin' && @model_class && @model_class <= User
        admin_class = Users::Admin
        @fixture.each do |key, value|
          next unless value.is_a?(String) && key.include?('_')
          
          enum_type = key.to_s.gsub(/(_)(.+)/, '')
          name = ::ActiveRecord::Base.pluralize_table_names ? enum_type.pluralize : enum_type
          
          # Add nil checks to avoid "undefined method '[]' for nil" errors
          if admin_class.defined_enums && 
             admin_class.defined_enums[name] && 
             admin_class.defined_enums[name][value]
            @fixture[key] = admin_class.defined_enums[name][value]
          end
        end
      else
        original_resolve_enums
      end
    end
  end
end
