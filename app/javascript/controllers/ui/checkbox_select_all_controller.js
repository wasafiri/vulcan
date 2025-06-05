import { Controller } from "@hotwired/stimulus"
import { applyTargetSafety } from "../../mixins/target_safety"

// Connects to data-controller="checkbox-select-all"
class CheckboxSelectAllController extends Controller {
  static targets = ["select", "checkbox", "actionButton", "downloadForm", "markPrintedForm"]

  connect() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("CheckboxSelectAll controller connected")
    }
    this.updateButtonState()
    this.updateFormFields()
  }

  selectAll() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("Select All clicked")
    }
    
    if (!this.hasRequiredTargets('select', 'checkbox')) {
      return;
    }

    const isChecked = this.selectTarget.checked
    
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    
    this.updateButtonState()
    this.updateFormFields()
  }
  
  checkboxChanged() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("Checkbox changed")
    }
    
    if (!this.hasRequiredTargets('select', 'checkbox')) {
      return;
    }

    // Update the "select all" checkbox state based on individual checkboxes
    const allChecked = this.checkboxTargets.every(checkbox => checkbox.checked)
    const anyChecked = this.checkboxTargets.some(checkbox => checkbox.checked)
    
    this.selectTarget.checked = allChecked
    this.updateButtonState(anyChecked)
    this.updateFormFields()
  }
  
  updateButtonState(anyChecked = null) {
    if (anyChecked === null && this.hasCheckboxTargets) {
      anyChecked = this.checkboxTargets.some(checkbox => checkbox.checked)
    }
    
    // Update all submit buttons using target safety
    this.withTargets('actionButton', (buttons) => {
      buttons.forEach(button => {
        button.disabled = !anyChecked
      })
    });
  }
  
  // Update the form fields for both forms
  updateFormFields() {
    // Update the download form
    this.withTarget('downloadForm', (form) => {
      this.updateFormWithIds(form);
    });
    
    // Update the mark as printed form
    this.withTarget('markPrintedForm', (form) => {
      this.updateFormWithIds(form);
    });
  }
  
  // Helper method to update a form with letter_ids
  updateFormWithIds(form) {
    // Clear any existing hidden fields from the form
    const existingFields = form.querySelectorAll('input[name="letter_ids[]"]');
    existingFields.forEach(field => field.remove());
    
    // Get all checked checkboxes using target safety
    if (!this.hasCheckboxTargets) return;
    
    const checkedBoxes = this.checkboxTargets.filter(checkbox => checkbox.checked);
    
    // Add hidden field for each selected checkbox to the form
    checkedBoxes.forEach(checkbox => {
      const hiddenInput = document.createElement('input');
      hiddenInput.type = 'hidden';
      hiddenInput.name = 'letter_ids[]';
      hiddenInput.value = checkbox.value;
      form.appendChild(hiddenInput);
    });
  }
}

// Apply target safety mixin
applyTargetSafety(CheckboxSelectAllController)

export default CheckboxSelectAllController
