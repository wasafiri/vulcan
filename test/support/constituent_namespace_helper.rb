module ConstituentNamespaceHelper
  # This helper is used to load the Constituent namespace controllers
  # without conflicting with the Constituent model
  def self.load_controller(controller_path)
    # Store the original Constituent constant
    original_constituent = Constituent

    # Undefine the Constituent constant temporarily
    Object.send(:remove_const, :Constituent) if defined?(Constituent)

    # Define Constituent as a module
    Object.const_set(:Constituent, Module.new)

    # Load the controller
    require Rails.root.join(controller_path)

    # Restore the original Constituent constant
    Object.send(:remove_const, :Constituent)
    Object.const_set(:Constituent, original_constituent)
  end
end
