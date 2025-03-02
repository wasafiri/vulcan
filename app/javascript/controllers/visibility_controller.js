// app/javascript/controllers/visibility_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "fieldConfirmation", "icon", "status"]
  
  static values = {
    timeout: { type: Number, default: 5000 } // 5 seconds timeout
  }
  
  initialize() {
    this.visibilityTimeout = null;
    console.log("Visibility controller initialized", this.element);
    
    // For testing purposes, check if a global timeout is set
    if (typeof window.passwordVisibilityTimeout !== 'undefined') {
      this.timeoutValue = window.passwordVisibilityTimeout;
      console.log(`Using custom timeout: ${this.timeoutValue}ms`);
    }
    
    // Debug: Log available targets
    console.log("Has field target:", this.hasFieldTarget);
    console.log("Has fieldConfirmation target:", this.hasFieldConfirmationTarget);
    console.log("Has status target:", this.hasStatusTarget);
    
    if (this.hasFieldTarget) {
      console.log("Field target:", this.fieldTarget);
    }
    
    if (this.hasFieldConfirmationTarget) {
      console.log("Field confirmation target:", this.fieldConfirmationTarget);
    }
  }
  
  // This is the method called from the HTML
  togglePassword(event) {
    console.log("togglePassword called", event.currentTarget);
    
    // Prevent the button from submitting the form
    event.preventDefault();
    
    // Get the button
    const button = event.currentTarget;
    
    // Get the container (parent with class "relative")
    const container = button.closest(".relative");
    console.log("Container found:", container);
    
    // Find the password field
    let passwordField;
    
    // First try to find the field using Stimulus targets
    if (this.hasFieldTarget && container.contains(this.fieldTarget)) {
      console.log("Using field target from Stimulus");
      passwordField = this.fieldTarget;
    } else if (this.hasFieldConfirmationTarget && container.contains(this.fieldConfirmationTarget)) {
      console.log("Using fieldConfirmation target from Stimulus");
      passwordField = this.fieldConfirmationTarget;
    } else {
      // Fallback to direct DOM query within the container
      console.log("Using fallback method to find password field");
      
      // Find the input that's a direct child of the container
      const inputs = Array.from(container.querySelectorAll("input"));
      console.log("All inputs in container:", inputs);
      
      // Find the input that's a direct child or closest to the button
      passwordField = inputs.find(input => {
        // Check if it's a password field
        return input.type === 'password' || input.type === 'text';
      });
      
      if (!passwordField && inputs.length > 0) {
        console.log("No password field found, using first input as fallback");
        passwordField = inputs[0];
      }
    }
    
    if (!passwordField) {
      console.error("Password field not found");
      // Log all input fields in the container for debugging
      const inputs = container.querySelectorAll("input");
      console.log("Available inputs in container:", inputs);
      return;
    }
    
    console.log("Password field found:", passwordField);
    
    // Determine current and new visibility state
    const isVisible = passwordField.type === "text";
    const newVisibility = !isVisible;
    
    console.log("Toggling visibility to:", newVisibility ? "visible" : "hidden");
    
    // Toggle the type
    passwordField.type = newVisibility ? "text" : "password";
    
    // Update accessibility attributes
    button.setAttribute("aria-pressed", newVisibility);
    button.setAttribute("aria-label", newVisibility ? "Hide password" : "Show password");
    
    // Toggle icon class
    button.classList.toggle("eye-open", newVisibility);
    button.classList.toggle("eye-closed", !newVisibility);
    
    // Update status for screen readers
    const statusElement = this.hasStatusTarget ? this.statusTarget : 
                          document.getElementById(passwordField.getAttribute("aria-describedby"));
    
    if (statusElement) {
      statusElement.textContent = newVisibility ? "Password is visible" : "Password is hidden";
    }
    
    // Security: Auto-hide after timeout
    if (newVisibility && this.timeoutValue > 0) {
      clearTimeout(this.visibilityTimeout);
      this.visibilityTimeout = setTimeout(() => {
        console.log("Auto-hiding password after timeout");
        passwordField.type = "password";
        button.setAttribute("aria-pressed", "false");
        button.setAttribute("aria-label", "Show password");
        button.classList.remove("eye-open");
        button.classList.add("eye-closed");
        
        // Update status for screen readers
        if (statusElement) {
          statusElement.textContent = "Password is hidden";
        }
      }, this.timeoutValue);
    } else {
      clearTimeout(this.visibilityTimeout);
    }
  }
  
  disconnect() {
    // Clean up timeout when controller is disconnected
    clearTimeout(this.visibilityTimeout);
  }
}
