import { Controller } from "@hotwired/stimulus"

// Handles showing/hiding proof upload and rejection sections based on status
export default class extends Controller {
  static targets = ["uploadSection", "rejectionSection"]

  connect() {
    // Initialize sections based on current selection
    const selectedStatus = this.element.querySelector('input[type="radio"]:checked')
    if (selectedStatus) {
      this.toggle({ target: selectedStatus })
    }
  }

  // Toggle sections based on status
  toggle(event) {
    const isApproved = event.target.value === "approved"
    
    // Use data targets instead of getElementById
    if (isApproved) {
      this.uploadSectionTarget.hidden = false
      this.rejectionSectionTarget.hidden = true
    } else {
      this.uploadSectionTarget.hidden = true
      this.rejectionSectionTarget.hidden = false
    }
  }
}
