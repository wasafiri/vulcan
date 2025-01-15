// app/javascript/controllers/visibility_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "icon", "status"]

  togglePassword() {
    const field = this.fieldTarget
    const isVisible = field.type === "text"
    
    // Toggle password visibility
    field.type = isVisible ? "password" : "text"
    
    // Update aria-pressed state
    this.element.setAttribute("aria-pressed", !isVisible)
    
    // Update status for screen readers
    this.statusTarget.textContent = `Password is ${isVisible ? 'hidden' : 'visible'}`
    
    // Update icon
    const showPath = "M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
    const hidePath = "M13.359 11.238C13.42 11.869 13.42 12.131 13.359 12.762M10.641 11.238C10.58 11.869 10.58 12.131 10.641 12.762M3 8L15 8M9 15L15 15"
    
    this.iconTarget.querySelector("path").setAttribute("d", isVisible ? showPath : hidePath)
  }
}