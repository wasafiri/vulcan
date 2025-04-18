// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import Chart from "chart.js/auto"
import * as WebAuthnJSON from "@github/webauthn-json"
import Auth from "./auth"
import "./controllers"
import "./controllers/debug_helper"

// Make Chart.js available globally
window.Chart = Chart
// Make WebAuthnJSON and Auth available globally if needed for debugging, or remove if not
window.WebAuthnJSON = WebAuthnJSON
window.Auth = Auth

// Set a global timeout for password visibility (for testing purposes)
window.passwordVisibilityTimeout = 5000;

// Define the global togglePasswordVisibility function
window.togglePasswordVisibility = function(button, timeout = 5000) {
  console.log("Global togglePasswordVisibility called", button);
  
  // Find the password field and status element
  const container = button.closest('.relative');
  const passwordField = container.querySelector('input[type="password"], input[type="text"]');
  const statusElement = document.getElementById(passwordField.getAttribute('aria-describedby'));
  
  if (!passwordField) {
    console.error('Password field not found');
    return;
  }
  
  console.log("Password field found:", passwordField);
  
  // Determine current and new visibility state
  const isVisible = passwordField.type === 'text';
  const newVisibility = !isVisible;
  
  console.log("Toggling visibility to:", newVisibility ? "visible" : "hidden");
  
  // Toggle the type
  passwordField.type = newVisibility ? 'text' : 'password';
  
  // Update accessibility attributes
  button.setAttribute('aria-pressed', newVisibility);
  button.setAttribute('aria-label', newVisibility ? 'Hide password' : 'Show password');
  
  // Toggle icon class
  button.classList.toggle('eye-open', newVisibility);
  button.classList.toggle('eye-closed', !newVisibility);
  
  // Update status for screen readers
  if (statusElement) {
    statusElement.textContent = newVisibility ? 'Password is visible' : 'Password is hidden';
  }
  
  // Clear any existing timeout
  if (button._visibilityTimeout) {
    clearTimeout(button._visibilityTimeout);
    button._visibilityTimeout = null;
  }
  
  // Security: Auto-hide after timeout if enabled
  if (newVisibility && timeout > 0) {
    button._visibilityTimeout = setTimeout(() => {
      console.log("Auto-hiding password after timeout");
      passwordField.type = 'password';
      button.setAttribute('aria-pressed', 'false');
      button.setAttribute('aria-label', 'Show password');
      button.classList.remove('eye-open');
      button.classList.add('eye-closed');
      
      // Update status for screen readers
      if (statusElement) {
        statusElement.textContent = 'Password is hidden';
      }
      
      button._visibilityTimeout = null;
    }, timeout);
  }
};

// Log when application.js is loaded
console.log("Application.js loaded - password visibility is handled by global function");

ActiveStorage.start()
