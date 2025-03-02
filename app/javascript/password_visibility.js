/**
 * Toggles the visibility of a password field
 * 
 * @param {HTMLElement} button - The button element that was clicked
 * @param {number} timeout - Timeout in milliseconds before hiding password again (0 to disable)
 */
function togglePasswordVisibility(button, timeout = 5000) {
  // Find the password field and status element
  const container = button.closest('.relative');
  const passwordField = container.querySelector('input[type="password"], input[type="text"]');
  const statusElement = document.getElementById(passwordField.getAttribute('aria-describedby'));
  
  if (!passwordField) {
    console.error('Password field not found');
    return;
  }
  
  // Determine current and new visibility state
  const isVisible = passwordField.type === 'text';
  const newVisibility = !isVisible;
  
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
}

// Export the function for use in other files
export { togglePasswordVisibility };
