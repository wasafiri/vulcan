import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "codeInput"]

  connect() {
    console.log("TOTP Form controller connected")
    this.enableSubmitButton()
    
    // Store bound method reference for proper cleanup
    this._boundHandleStreamRender = this.handleStreamRender.bind(this)
    
    // Listen for stream renders targeting our container
    document.addEventListener("turbo:before-stream-render", this._boundHandleStreamRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this._boundHandleStreamRender)
    console.log("TOTP Form controller disconnected")
  }

  // Called when the form submission starts via Turbo
  submitStart() {
    this.disableSubmitButton()
    console.log("Form submitted, button disabled")
  }

  // Called BEFORE a Turbo Stream action is processed
  handleStreamRender(event) {
    // Ensure the stream is targeting our main content area
    const targetId = event.target.target
    if (targetId !== 'main-content') return

    // Check the incoming stream content for an error alert
    const newContent = event.detail.newStream.templateElement.content
    if (newContent.querySelector('[role="alert"]')) {
      console.log("Stream rendering error found, scheduling button enable.")
      // Schedule enabling the button and focusing input *after* the render completes
      requestAnimationFrame(() => {
        // Find the button/input in the *newly rendered* DOM
        const newForm = document.getElementById('main-content')?.querySelector('[data-controller="totp-form"]')
        if (newForm) {
          const newButton = newForm.querySelector('[data-totp-form-target="submitButton"]')
          const newInput = newForm.querySelector('[data-totp-form-target="codeInput"]')
          if (newButton) {
            newButton.disabled = false
            console.log("Button re-enabled after stream render.")
          }
          if (newInput) {
            newInput.focus()
            console.log("Input focused after stream render.")
          }
        } else {
           console.warn("Could not find new form after stream render to re-enable button.")
        }
      })
    } else {
      console.log("Stream rendering success or no error.")
    }
  }

  disableSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  enableSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      console.log("Submit button enabled")
    }
  }
  
  focusCodeInput() {
    if (this.hasCodeInputTarget) {
      this.codeInputTarget.focus()
      console.log("Code input field focused")
    }
  }
}
