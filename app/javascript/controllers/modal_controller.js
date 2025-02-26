import { Controller } from "@hotwired/stimulus"

// Declare targets for type safety and better structure
export default class extends Controller {
  static targets = [ "container", "overlay" ]

  connect() {
    // Ensure modal is hidden on connect
    this.close()

    // Handle escape key
    this._handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleKeydown)
  }

  open() {
    this.containerTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")

    // Focus first input
    const firstInput = this.containerTarget.querySelector("input, textarea")
    if (firstInput) {
      firstInput.focus()
    }
  }

  close(event) {
    event?.preventDefault()
    this.containerTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  // Prevent clicks inside modal from closing it
  preventClose(event) {
    event.stopPropagation()
  }

  // Handle form submission
  handleSubmit(event) {
    const form = event.target
    const isValid = form.checkValidity()

    if (!isValid) {
      event.preventDefault()
      // Show validation messages
      form.reportValidity()
    } else {
      // Close modal after successful submission
      this.close()
    }
  }

}
