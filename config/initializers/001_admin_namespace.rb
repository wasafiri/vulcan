# frozen_string_literal: true

# This initializer deliberately has a low number (001_) to ensure it loads very early.
# It establishes Admin as a module before any other code might attempt to define it 
# as a class, avoiding the "Admin is not a module" error.

# Create the Admin module before any other code tries to define it
module Admin
  # This is a namespace module for admin controllers, helpers, and views
end
