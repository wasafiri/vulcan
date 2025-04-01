import { Controller } from "@hotwired/stimulus"

// Handles showing/hiding proof upload and rejection sections based on status
export default class extends Controller {
  static targets = ["uploadSection", "rejectionSection"]

  connect() {
    // Initialize sections based on current selection with a small delay
    // to ensure the DOM is fully loaded and the radio button state is recognized
    setTimeout(() => {
      const selectedStatus = this.element.querySelector('input[type="radio"]:checked')
      if (selectedStatus) {
        console.log('Initial status:', selectedStatus.value)
        this.toggle({ target: selectedStatus })
      } else {
        // Fallback: If no radio is checked, default to showing upload section
        console.log('No radio checked, defaulting to upload section')
        if (this.hasUploadSectionTarget) this.uploadSectionTarget.hidden = false
        if (this.hasRejectionSectionTarget) this.rejectionSectionTarget.hidden = true
      }
    }, 100) // Increased delay to ensure DOM is fully loaded
  }

  // Toggle sections based on status
  toggle(event) {
    // Check for both "approved" and "accepted" values to support both proofs and medical certifications
    const isApproved = event.target.value === "approved" || event.target.value === "accepted"
    console.log('Toggle called:', event.target.value, 'isApproved:', isApproved)
    
    // Explicitly show/hide both sections to ensure proper toggling
    if (isApproved) {
      if (this.hasUploadSectionTarget) {
        this.uploadSectionTarget.hidden = false
        console.log('Showing upload section')
      }
      if (this.hasRejectionSectionTarget) {
        this.rejectionSectionTarget.hidden = true
        console.log('Hiding rejection section')
      }
    } else {
      if (this.hasUploadSectionTarget) {
        this.uploadSectionTarget.hidden = true
        console.log('Hiding upload section')
      }
      if (this.hasRejectionSectionTarget) {
        this.rejectionSectionTarget.hidden = false
        console.log('Showing rejection section')
      }
    }
  }
}
