import { Controller } from "@hotwired/stimulus"

// This controller manages the guardian relationship field visibility
export default class extends Controller {
  static targets = ["relationshipField", "checkbox", "select"]
  
  connect() {
    this.updateVisibility()
    
    // If we have relationship select, ensure it's required when checkbox is checked
    if (this.hasSelectTarget) {
      this.updateSelectRequired()
    }
  }
  
  toggleVisibility() {
    this.updateVisibility()
    this.updateSelectRequired()
  }
  
  // Show the relationship field only when the guardian checkbox is checked
  updateVisibility() {
    if (this.hasCheckboxTarget && this.hasRelationshipFieldTarget) {
      if (this.checkboxTarget.checked) {
        this.relationshipFieldTarget.classList.remove('hidden')
      } else {
        this.relationshipFieldTarget.classList.add('hidden')
      }
    }
  }
  
  // Make the select field required only when the guardian checkbox is checked
  updateSelectRequired() {
    if (this.hasSelectTarget && this.hasCheckboxTarget) {
      this.selectTarget.required = this.checkboxTarget.checked
      this.selectTarget.setAttribute('aria-required', this.checkboxTarget.checked)
    }
  }
}
