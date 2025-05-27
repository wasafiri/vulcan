import { Controller } from "@hotwired/stimulus"

/**
 * Form Validation Controller
 * 
 * Provides client-side validation for paper application forms.
 * Works in conjunction with HTML5 validation and server-side validation.
 */
export default class extends Controller {
  static targets = [
    "form",
    "errorContainer"
  ]

  connect() {
    // Store bound method reference for proper cleanup
    this._boundValidateForm = this.validateForm.bind(this)
    
    // Set up form validation hooks
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', this._boundValidateForm);
    }
  }

  disconnect() {
    // Clean up event listeners
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener('submit', this._boundValidateForm);
    }
  }

  /**
   * Custom form validation before submission
   * @param {Event} event Form submission event
   */
  validateForm(event) {
    let isValid = true;
    const errorContainer = this.getOrCreateErrorContainer();
    
    // Clear any existing errors
    errorContainer.innerHTML = '';
    
    // Validate income proof
    isValid = this.validateProofSection('income_proof', errorContainer) && isValid;
    
    // Validate residency proof
    isValid = this.validateProofSection('residency_proof', errorContainer) && isValid;
    
    // If invalid, prevent form submission
    if (!isValid) {
      event.preventDefault();
      
      // Scroll to the error container
      errorContainer.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
    
    return isValid;
  }
  
  /**
   * Validate a proof document section
   * @param {string} proofType Type of proof (income_proof or residency_proof)
   * @param {HTMLElement} errorContainer Container for error messages
   * @returns {boolean} Whether the section is valid
   */
  validateProofSection(proofType, errorContainer) {
    let isValid = true;
    
    // Check if accept radio is selected
    const acceptRadio = document.getElementById(`accept_${proofType}`);
    if (acceptRadio?.checked) {
      // Verify file is uploaded
      const fileInput = document.querySelector(`input[name="${proofType}"]`);
      if (!fileInput || !fileInput.files || fileInput.files.length === 0) {
        this.addError(errorContainer, `Please upload a ${proofType.replace('_', ' ')} document`);
        isValid = false;
      }
    } 
    // Check if reject radio is selected
    else if (document.getElementById(`reject_${proofType}`)?.checked) {
      // Verify rejection reason is selected
      const reasonSelect = document.querySelector(`select[name="${proofType}_rejection_reason"]`);
      if (!reasonSelect || !reasonSelect.value) {
        this.addError(errorContainer, `Please select a reason for rejecting ${proofType.replace('_', ' ')}`);
        isValid = false;
      }
    } 
    // Neither accept nor reject selected
    else {
      this.addError(errorContainer, `Please select an option for ${proofType.replace('_', ' ')}`);
      isValid = false;
    }
    
    return isValid;
  }
  
  /**
   * Create or get the error container for form validation
   * @returns {HTMLElement} The error container element
   */
  getOrCreateErrorContainer() {
    if (this.hasErrorContainerTarget) {
      // Clear existing errors
      this.errorContainerTarget.innerHTML = '';
      return this.errorContainerTarget;
    }
    
    // Create a new error container if target isn't available
    let errorContainer = document.querySelector('.form-error-container');
    if (!errorContainer) {
      errorContainer = document.createElement('div');
      errorContainer.className = 'form-error-container bg-red-100 border border-red-400 text-red-700 p-4 rounded mb-4';
      this.element.insertBefore(errorContainer, this.element.firstChild);
    } else {
      // Clear existing errors
      errorContainer.innerHTML = '';
    }
    return errorContainer;
  }
  
  /**
   * Add an error message to the error container
   * @param {HTMLElement} container The error container
   * @param {string} message The error message
   */
  addError(container, message) {
    const errorMessage = document.createElement('p');
    errorMessage.textContent = message;
    errorMessage.className = 'mb-1 last:mb-0';
    container.appendChild(errorMessage);
  }
}
