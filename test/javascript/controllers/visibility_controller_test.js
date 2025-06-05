import { Application } from "@hotwired/stimulus"
import VisibilityController from "controllers/ui/visibility_controller"

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
    // Set up DOM structure that matches what the controller expects
    document.body.innerHTML = `
      <div data-controller="visibility">
        <div class="relative">
          <input type="password" id="password" data-visibility-target="field" />
          <button type="button" data-action="click->visibility#togglePassword">Toggle</button>
        </div>
        <div class="relative">
          <input type="password" id="confirmation" data-visibility-target="fieldConfirmation" />
          <button type="button" data-action="click->visibility#togglePassword">Toggle Confirmation</button>
        </div>
        <div id="status" data-visibility-target="status"></div>
        <div class="relative">
          <input type="password" id="no-targets-field" />
          <button type="button" data-action="click->visibility#togglePassword">No Targets Toggle</button>
        </div>
      </div>
    `
    
    // Set up Stimulus controller
    application = Application.start()
    application.register("visibility", VisibilityController)
    
    controller = application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller="visibility"]'),
      "visibility"
    )
    
    element = document.querySelector("[data-controller='visibility']")
    passwordField = element.querySelector("#password")
    confirmationField = element.querySelector("#confirmation")
    toggleButton = element.querySelector("button[data-action*='togglePassword']")
    confirmationToggleButton = element.querySelectorAll("button[data-action*='togglePassword']")[1]
    statusElement = element.querySelector("#status")
    
    // Mock setTimeout and clearTimeout
    jest.useFakeTimers()
  })
  
  afterEach(() => {
    jest.useRealTimers()
    application.stop()
    document.body.innerHTML = ""
  })
  
  test("toggles password visibility when button is clicked", () => {
    const passwordField = document.getElementById("password")
    const toggleButton = document.querySelector('button[data-action*="togglePassword"]')
    
    // Initial state
    expect(passwordField.type).toBe("password")
    
    // Click the toggle button
    toggleButton.click()
    
    // Password should be visible
    expect(passwordField.type).toBe("text")
    expect(toggleButton.getAttribute("aria-pressed")).toBe("true")
    expect(toggleButton.getAttribute("aria-label")).toBe("Hide password")
    expect(toggleButton.classList.contains("eye-open")).toBe(true)
  })
  
  test("toggles confirmation password visibility when button is clicked", () => {
    const confirmationField = document.getElementById("confirmation")
    const confirmationToggleButton = document.querySelectorAll('button[data-action*="togglePassword"]')[1]
    
    // Initial state
    expect(confirmationField.type).toBe("password")
    
    // Click the toggle button
    confirmationToggleButton.click()
    
    // Password should be visible
    expect(confirmationField.type).toBe("text")
    expect(confirmationToggleButton.getAttribute("aria-pressed")).toBe("true")
    expect(confirmationToggleButton.getAttribute("aria-label")).toBe("Hide password")
    expect(confirmationToggleButton.classList.contains("eye-open")).toBe(true)
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
  
  test("works with multiple togglePassword buttons", () => {
    // Initially password is hidden
    expect(passwordField.type).toBe("password")
    
    // Click the first toggle button to show password
    toggleButton.click()
    expect(passwordField.type).toBe("text")
    
    // Click the confirmation toggle button - this should work with the confirmation field
    confirmationToggleButton.click()
    expect(confirmationField.type).toBe("text")
    
    // Click the first toggle button again to hide password
    toggleButton.click()
    expect(passwordField.type).toBe("password")
    
    // Confirmation should still be visible
    expect(confirmationField.type).toBe("text")
  })
  
  test("works without targets if they're not available", () => {
    const noTargetsField = document.getElementById("no-targets-field")
    const noTargetsButton = document.querySelectorAll('button[data-action*="togglePassword"]')[2]
    
    // Initial state
    expect(noTargetsField.type).toBe("password")
    
    // Click the toggle button
    noTargetsButton.click()
    
    // Password should be visible
    expect(noTargetsField.type).toBe("text")
    
    // Click again
    noTargetsButton.click()
    
    // Password should be hidden again
    expect(noTargetsField.type).toBe("password")
  })
  
  test("updates status element when toggling", () => {
    const passwordField = document.getElementById("password")
    const toggleButton = document.querySelector('button[data-action*="togglePassword"]')
    const statusElement = document.getElementById("status")
    
    // Click the toggle button
    toggleButton.click()
    
    expect(statusElement.textContent).toBe("Password is visible")
    
    // Click again to hide
    toggleButton.click()
    
    expect(statusElement.textContent).toBe("Password is hidden")
  })
})
