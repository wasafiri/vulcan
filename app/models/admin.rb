# frozen_string_literal: true

# This file acts as a bridge between:
# 1. The Admin module needed for namespacing (Admin::BaseController, etc.)
# 2. The Users::Admin class needed for Single Table Inheritance

# The Admin module is defined by the initializer 001_admin_namespace.rb
# This ensures it's loaded early in the boot process

# For STI usage, redirect the 'Admin' constant to Users::Admin
# when used in the context of User type='Admin'
#
# The actual mapping between type="Admin" and Users::Admin is done in
# config/initializers/sti_type_mapping.rb using ActiveRecord hooks

# Include the actual implementation
require_dependency 'users/admin'
