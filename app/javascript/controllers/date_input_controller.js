import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden"]

  connect() {
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener('input', this.handleInput.bind(this))
      this.inputTarget.addEventListener('blur', this.handleBlur.bind(this))
    }
  }

  disconnect() {
    if (this.hasInputTarget) {
      this.inputTarget.removeEventListener('input', this.handleInput.bind(this))
      this.inputTarget.removeEventListener('blur', this.handleBlur.bind(this))
    }
  }

  handleInput(event) {
    const input = event.target
    let value = input.value.replace(/\D/g, '')
    
    // Auto-format as user types
    if (value.length > 2) value = value.slice(0, 2) + '/' + value.slice(2)
    if (value.length > 5) value = value.slice(0, 5) + '/' + value.slice(5, 9)
    
    input.value = value
  }

  handleBlur(event) {
    const input = event.target
    let value = input.value // Changed from const to let
    
    // Only validate if we have a complete date
    if (value.length >= 8) {
      // Check for MMDDYYYY format (8 digits, no slashes)
      if (/^\d{8}$/.test(value)) {
        value = `${value.slice(0, 2)}/${value.slice(2, 4)}/${value.slice(4, 8)}`
        // Update the input field visually immediately for consistency
        input.value = value 
      }
      
      const parts = value.split('/')
      if (parts.length === 3) {
        let [month, day, year] = parts.map(p => parseInt(p, 10))
        
        // Handle 2-digit years
        if (year < 100) {
          year += year >= 50 ? 1900 : 2000
        }
        
        const date = new Date(year, month - 1, day)
        if (date.getMonth() === month - 1 && date.getDate() === day && year >= 1900 && year <= new Date().getFullYear()) {
          // Valid date - update hidden field for Rails
          if (this.hasHiddenTarget) {
            this.hiddenTarget.value = `${year}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`
          }
          // Ensure the visual input is also correctly formatted after validation
          input.value = `${month.toString().padStart(2, '0')}/${day.toString().padStart(2, '0')}/${year}`
        }
      }
    }
    // Consider clearing hidden field if input is invalid/incomplete?
    // else if (this.hasHiddenTarget) { 
    //   this.hiddenTarget.value = "" 
    // }
  }
}
