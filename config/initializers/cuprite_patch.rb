# frozen_string_literal: true

# Add a patch for Cuprite to silence warnings about unsupported options
# This eliminates the "Options passed to Node#set but Cuprite doesn't currently support any - ignoring" warnings

if defined?(Capybara::Cuprite)
  # Patch Capybara::Cuprite::Node to silence warnings about options
  module CapybaraCupriteNodePatch
    def set(value, options = {})
      if !options.empty?
        # Silence the warning by not displaying it
        # The original method in Cuprite will show a warning for non-empty options
        original_set(value)
      else
        # Call the original method as normal
        original_set(value, options)
      end
    end
  end

  # Apply the patch to Capybara::Cuprite::Node
  if defined?(Capybara::Cuprite::Node)
    # Save reference to the original set method
    Capybara::Cuprite::Node.class_eval do
      alias_method :original_set, :set
    end

    # Apply our patch
    Capybara::Cuprite::Node.prepend CapybaraCupriteNodePatch
  end
end
