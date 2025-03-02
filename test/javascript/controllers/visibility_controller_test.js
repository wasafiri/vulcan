import { Application } from "@hotwired/stimulus"
import VisibilityController from "controllers/visibility_controller"

describe("VisibilityController", () => {
  let application
  let controller
  let element
  let passwordField
  let confirmationField
  let toggleButton
  let confirmationToggleButton
  let statusElement
  
  beforeEach(() => {
    // Set up DOM
    document.body.innerHTML = `
      <div data-controller="visibility">
        <div class="relative">
          <input 
            type="password" 
            id="password" 
            data-visibility-target="field"
            aria-describedby="password-visibility-status">
          <button 
            id="togglePassword" 
            class="eye-closed"
            data-action="visibility#togglePassword"
            aria-label="Show password" 
            aria-pressed="false">
            <svg data-visibility-target="icon"></svg>
          </button>
          <div 
            id="password-visibility-status"
            data-visibility-target="status"
            aria-live="polite" 
            class="sr-only">
            Password is hidden
          </div>
        </div>
        
        <div class="relative">
          <input 
            type="password" 
            id="password_confirmation" 
            data-visibility-target="fieldConfirmation"
            aria-describedby="confirmation-visibility-status">
          <button 
            id="toggleConfirmation" 
            class="eye-closed"
            data-action="visibility#toggle"
            aria-label="Show password" 
            aria-pressed="false">
            <svg></svg>
          </button>
        </div>
      </div>
    `
    
    // Set up Stimulus controller
    application = Application.start()
    application.register("visibility", VisibilityController)
    
    element = document.querySelector("[data-controller='visibility']")
    passwordField = element.querySelector("#password")
    confirmationField = element.querySelector("#password_confirmation")
    toggleButton = element.querySelector("#togglePassword")
    confirmationToggleButton = element.querySelector("#toggleConfirmation")
    statusElement = element.querySelector("[data-visibility-target='status']")
    
    // Mock setTimeout and clearTimeout
    jest.useFakeTimers()
  })
  
  afterEach(() => {
    jest.useRealTimers()
  })
  
  test("toggles password visibility when button is clicked", () => {
    // Initial state
    expect(passwordField.type).toBe("password")
    expect(toggleButton.getAttribute("aria-pressed")).toBe("false")
    expect(statusElement.textContent.trim()).toBe("Password is hidden")
    
    // Click the toggle button
    toggleButton.click()
    
    // Password should be visible
    expect(passwordField.type).toBe("text")
    expect(toggleButton.getAttribute("aria-pressed")).toBe("true")
    expect(toggleButton.getAttribute("aria-label")).toBe("Hide password")
    expect(toggleButton.classList.contains("eye-open")).toBe(true)
    expect(toggleButton.classList.contains("eye-closed")).toBe(false)
    expect(statusElement.textContent.trim()).toBe("Password is visible")
    
    // Click again to hide
    toggleButton.click()
    
    // Password should be hidden again
    expect(passwordField.type).toBe("password")
    expect(toggleButton.getAttribute("aria-pressed")).toBe("false")
    expect(toggleButton.getAttribute("aria-label")).toBe("Show password")
    expect(toggleButton.classList.contains("eye-open")).toBe(false)
    expect(toggleButton.classList.contains("eye-closed")).toBe(true)
    expect(statusElement.textContent.trim()).toBe("Password is hidden")
  })
  
  test("toggles confirmation password visibility when button is clicked", () => {
    // Initial state
    expect(confirmationField.type).toBe("password")
    expect(confirmationToggleButton.getAttribute("aria-pressed")).toBe("false")
    
    // Click the toggle button
    confirmationToggleButton.click()
    
    // Password should be visible
    expect(confirmationField.type).toBe("text")
    expect(confirmationToggleButton.getAttribute("aria-pressed")).toBe("true")
    expect(confirmationToggleButton.getAttribute("aria-label")).toBe("Hide password")
    expect(confirmationToggleButton.classList.contains("eye-open")).toBe(true)
    expect(confirmationToggleButton.classList.contains("eye-closed")).toBe(false)
    
    // Click again to hide
    confirmationToggleButton.click()
    
    // Password should be hidden again
    expect(confirmationField.type).toBe("password")
    expect(confirmationToggleButton.getAttribute("aria-pressed")).toBe("false")
    expect(confirmationToggleButton.getAttribute("aria-label")).toBe("Show password")
    expect(confirmationToggleButton.classList.contains("eye-open")).toBe(false)
    expect(confirmationToggleButton.classList.contains("eye-closed")).toBe(true)
  })
  
  test("automatically hides password after timeout", () => {
    // Set timeout value
    element.setAttribute("data-visibility-timeout-value", "5000")
    
    // Click to show password
    toggleButton.click()
    
    // Password should be visible
    expect(passwordField.type).toBe("text")
    expect(statusElement.textContent.trim()).toBe("Password is visible")
    
    // Fast-forward time
    jest.advanceTimersByTime(5000)
    
    // Password should be hidden again
    expect(passwordField.type).toBe("password")
    expect(toggleButton.getAttribute("aria-pressed")).toBe("false")
    expect(toggleButton.getAttribute("aria-label")).toBe("Show password")
    expect(toggleButton.classList.contains("eye-closed")).toBe(true)
    expect(statusElement.textContent.trim()).toBe("Password is hidden")
  })
  
  test("clears timeout when toggling back to hidden", () => {
    // Set timeout value
    element.setAttribute("data-visibility-timeout-value", "5000")
    
    // Click to show password
    toggleButton.click()
    
    // Password should be visible
    expect(passwordField.type).toBe("text")
    
    // Click again to hide before timeout
    toggleButton.click()
    
    // Password should be hidden
    expect(passwordField.type).toBe("password")
    
    // Fast-forward time
    jest.advanceTimersByTime(5000)
    
    // Password should still be hidden (no double-toggle)
    expect(passwordField.type).toBe("password")
  })
  
  test("handles missing password field gracefully", () => {
    // Remove the password field
    passwordField.remove()
    
    // Click should not throw error
    expect(() => {
      toggleButton.click()
    }).not.toThrow()
  })
  
  test("cleans up timeout on disconnect", () => {
    // Mock clearTimeout
    const originalClearTimeout = window.clearTimeout
    window.clearTimeout = jest.fn()
    
    // Set timeout and show password
    element.setAttribute("data-visibility-timeout-value", "5000")
    toggleButton.click()
    
    // Disconnect controller
    application.controllers[0].disconnect()
    
    // Should have called clearTimeout
    expect(window.clearTimeout).toHaveBeenCalled()
    
    // Restore original
    window.clearTimeout = originalClearTimeout
  })
  
  test("works with both togglePassword and toggle methods", () => {
    // Test the toggle method directly
    const toggleButton2 = document.createElement("button")
    toggleButton2.setAttribute("data-action", "visibility#toggle")
    element.querySelector(".relative").appendChild(toggleButton2)
    
    // Click the button that uses toggle
    toggleButton2.click()
    
    // Password should be visible
    expect(passwordField.type).toBe("text")
    
    // Click the original button that uses togglePassword
    toggleButton.click()
    
    // Password should be hidden again
    expect(passwordField.type).toBe("password")
  })
  
  test("works without targets if they're not available", () => {
    // Create a new element without targets
    document.body.innerHTML += `
      <div data-controller="visibility" id="no-targets">
        <div class="relative">
          <input type="password" id="password2">
          <button 
            data-action="visibility#toggle"
            aria-label="Show password" 
            aria-pressed="false">
            Toggle
          </button>
        </div>
      </div>
    `
    
    const noTargetsElement = document.getElementById("no-targets")
    const noTargetsButton = noTargetsElement.querySelector("button")
    const noTargetsField = noTargetsElement.querySelector("input")
    
    // Click the button
    noTargetsButton.click()
    
    // Password should be visible
    expect(noTargetsField.type).toBe("text")
    
    // Click again
    noTargetsButton.click()
    
    // Password should be hidden again
    expect(noTargetsField.type).toBe("password")
  })
  
  test("works with real-world HTML structure", () => {
    // Create a new element with the structure from the actual page
    document.body.innerHTML += `
      <div data-controller="visibility" id="real-world">
        <div class="relative">
          <input 
            type="password" 
            id="user_password" 
            data-visibility-target="field">
          <button 
            type="button"
            data-action="visibility#toggle"
            aria-label="Toggle password visibility"
            aria-pressed="false"
            class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500">
            <svg class="h-5 w-5" aria-hidden="true" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
          </button>
        </div>
        
        <div class="relative">
          <input 
            type="password" 
            id="user_password_confirmation" 
            data-visibility-target="fieldConfirmation">
          <button 
            type="button"
            data-action="visibility#toggle"
            aria-label="Toggle password visibility"
            aria-pressed="false"
            class="absolute right-2 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500">
            <svg class="h-5 w-5" aria-hidden="true" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
          </button>
        </div>
      </div>
    `
    
    const realWorldElement = document.getElementById("real-world")
    const passwordButton = realWorldElement.querySelector("button:first-of-type")
    const confirmationButton = realWorldElement.querySelector("button:last-of-type")
    const passwordInput = realWorldElement.querySelector("#user_password")
    const confirmationInput = realWorldElement.querySelector("#user_password_confirmation")
    
    // Click the password toggle button
    passwordButton.click()
    
    // Password should be visible
    expect(passwordInput.type).toBe("text")
    expect(passwordButton.getAttribute("aria-pressed")).toBe("true")
    
    // Click the confirmation toggle button
    confirmationButton.click()
    
    // Confirmation password should be visible
    expect(confirmationInput.type).toBe("text")
    expect(confirmationButton.getAttribute("aria-pressed")).toBe("true")
    
    // Click both buttons again
    passwordButton.click()
    confirmationButton.click()
    
    // Both passwords should be hidden again
    expect(passwordInput.type).toBe("password")
    expect(confirmationInput.type).toBe("password")
  })
})
