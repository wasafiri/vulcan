import { Controller } from "@hotwired/stimulus"

// Declare targets for type safety and better structure
export default class extends Controller {
  static targets = [
    "modal",        // The modal elements
    "backdrop",     // The modal backdrop
  ]

  static values = {
    open: { type: Boolean, default: false }
  }

  connect() {
    console.log('Modal controller connected')
    // Ensure modals start hidden
    this.modalTargets.forEach(modal => {
      modal.classList.add("hidden")
      console.log('Found modal:', modal.id)
    })
    this.openValue = false
    
    // Bind event handlers with proper context
    this._handleKeydown = this.handleKeydown.bind(this)
    this._handleClickOutside = this.handleClickOutside.bind(this)
    
    // Add event listeners
    document.addEventListener("keydown", this._handleKeydown)
    
    // Add click handler to all backdrop targets
    this.backdropTargets.forEach(backdrop => {
      backdrop.addEventListener("click", this._handleClickOutside)
    })
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener("keydown", this._handleKeydown)
    if (this.hasBackdropTarget) {
      this.backdropTarget.removeEventListener("click", this._handleClickOutside)
    }
  }

  // Action methods
  initialize() {
    // Store the modal's ID for external targeting
    this.modalIdValue = this.element.id
  }

  // Handle opening modal
  open(event) {
    event?.preventDefault()
    const targetModalId = event.currentTarget.dataset.modalId
    console.log('Opening modal:', targetModalId)
    console.log('Available modals:', this.modalTargets.map(m => m.id))
    
    const modal = this.modalTargets.find(m => m.id === targetModalId)
    if (!modal) {
      console.error('Modal not found:', targetModalId)
      return
    }

    // Hide all other modals
    this.modalTargets.forEach(m => m.classList.add("hidden"))

    // Show this modal
    modal.classList.remove("hidden")
    this.openValue = true
    console.log('Modal opened:', targetModalId)

    // Wait for modal to be visible then load PDFs
    requestAnimationFrame(() => {
      const iframes = modal.querySelectorAll('iframe')
      iframes.forEach(iframe => {
        // Store original src
        if (!iframe.dataset.originalSrc) {
          iframe.dataset.originalSrc = iframe.src
        }
        // Reset src to trigger load
        iframe.src = iframe.dataset.originalSrc
      })
    })
  }

  // Handle closing modal
  close(event) {
    event?.preventDefault()
    this.modalTargets.forEach(modal => modal.classList.add("hidden"))
    this.openValue = false
  }

  // Handle clicking outside modal
  handleClickOutside(event) {
    const backdrop = event.target.closest("[data-modal-target='backdrop']")
    if (backdrop) {
      this.close(event)
    }
  }

  // Handle escape key
  handleKeydown(event) {
    if (event.key === "Escape" && this.openValue) {
      this.close(event)
    }
  }

  // Handle form validation
  validateForm(event) {
    if (!this.hasReasonFieldTarget) return

    const reasonField = this.reasonFieldTarget
    if (!reasonField.value.trim()) {
      event.preventDefault()
      reasonField.classList.add('border-red-500')
      reasonField.focus()
      return
    }
    reasonField.classList.remove('border-red-500')
  }

}
