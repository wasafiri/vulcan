# frozen_string_literal: true

# This file acts as a bridge between:
# 1. The Admin module needed for namespacing (Admin::BaseController, etc.)
# 2. The Users::Administrator class needed for Single Table Inheritance

# The Admin module is defined by the initializer 001_admin_namespace.rb
# This ensures it's loaded early in the boot process

# For STI usage, redirect the 'Admin' constant to Users::Administrator
# when used in the context of User type='Administrator'
#
# The actual mapping between type="Administrator" and Users::Administrator is done in
# config/initializers/sti_type_mapping.rb using ActiveRecord hooks

# Include the actual implementation
require_dependency 'users/administrator'
