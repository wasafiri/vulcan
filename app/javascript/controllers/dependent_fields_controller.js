import { Controller } from "@hotwired/stimulus"
import { setVisible } from "../utils/visibility"
import { createFormChangeDebounce } from "../utils/debounce"

/**
 * Controller for managing dependent-related fields
 * 
 * Responsible for toggling dependent contact information visibility and handling
 * the "Same as Guardian's" functionality for both address and email.
 */
export default class extends Controller {
  static targets = ["fields", "addressFields", "sameAddressCheckbox", "sameEmailCheckbox", "relationshipType", "emailFieldContainer"]
  
  static values = {
    copyFromGuardian: Boolean
  }

  connect() {
    // Store bound method reference for proper cleanup
    this._boundHandleApplicantTypeChange = this.handleApplicantTypeChange.bind(this)
    
    // Set up debounced applicant type change handler
    this.debouncedApplicantTypeChange = createFormChangeDebounce(() => this.executeApplicantTypeChange())
    
    // Set initial state based on checkbox if available
    if (this.hasSameAddressCheckboxTarget) {
      this.toggleContactFields({ target: this.sameAddressCheckboxTarget });
    }
    
    // Set initial state for email checkbox
    if (this.hasSameEmailCheckboxTarget) {
      this.toggleEmailField({ target: this.sameEmailCheckboxTarget });
    }
    
    // Listen for applicant-type change events from ApplicantTypeController
    // Only set up the listener if applicant-type controller is present on the page
    this.formElement = this.element.closest("form")
    if (this.formElement && document.querySelector('[data-controller*="applicant-type"]')) {
      this.formElement.addEventListener(
        "applicant-type:applicantTypeChanged", 
        this._boundHandleApplicantTypeChange
      );
    }
  }
  
  disconnect() {
    // Clean up event listeners
    if (this.formElement) {
      this.formElement.removeEventListener(
        "applicant-type:applicantTypeChanged", 
        this._boundHandleApplicantTypeChange
      );
    }
    
    // Clean up debounced function
    this.debouncedApplicantTypeChange?.cancel();
  }
  
  /**
   * Toggle contact fields based on "Same as Guardian's Address" checkbox
   * @param {Event} event The change event from the checkbox
   */
  toggleContactFields(event) {
    if (!this.hasAddressFieldsTarget) return;
    
    const useGuardianContact = event.target.checked;
    this.copyFromGuardianValue = useGuardianContact;
    
    // Use utility to toggle visibility and required state for the container
    setVisible(this.addressFieldsTarget, !useGuardianContact);
    
    // Handle required attributes for individual input fields within the container
    const inputFields = this.addressFieldsTarget.querySelectorAll('input');
    inputFields.forEach(field => {
      setVisible(field, !useGuardianContact, { required: !useGuardianContact });
    });
    
    // Copy guardian contact info if needed
    if (useGuardianContact) {
      this.copyGuardianAddressInfo();
    }
  }
  
  /**
   * Toggle dependent email field based on "Use Guardian's Email" checkbox
   * @param {Event} event The change event from the checkbox
   */
  toggleEmailField(event) {
    const useGuardianEmail = event.target.checked;
    
    // Find the dependent email field
    const dependentEmailField = document.querySelector('input[name="dependent_attributes[email]"]');
    if (!dependentEmailField) return;
    
    // Update the hidden input value
    this.updateUseGuardianEmailInput(useGuardianEmail);
    
    // Use utility to handle email field visibility and required state
    setVisible(dependentEmailField, !useGuardianEmail, { required: !useGuardianEmail });
    
    // Handle email field container visibility if available
    if (this.hasEmailFieldContainerTarget) {
      setVisible(this.emailFieldContainerTarget, !useGuardianEmail);
    }
    
    // Copy guardian's email if needed
    if (useGuardianEmail) {
      const guardianEmailField = document.querySelector('input[name="guardian_attributes[email]"]');
      if (guardianEmailField && guardianEmailField.value) {
        dependentEmailField.value = guardianEmailField.value;
      } else {
        // Clear the field to ensure the server knows to use guardian's email
        dependentEmailField.value = '';
      }
    }
  }
  
  /**
   * Update the hidden form field to indicate whether to use guardian's email
   * @param {boolean} useGuardianEmail Whether to use guardian's email
   */
  updateUseGuardianEmailInput(useGuardianEmail) {
    // Get the visible checkbox - which may be our target
    const visibleCheckbox = this.hasSameEmailCheckboxTarget 
      ? this.sameEmailCheckboxTarget 
      : document.querySelector('input[name="use_guardian_email"]');
    
    // Ensure the checkbox value matches our parameter
    if (visibleCheckbox && visibleCheckbox.checked !== useGuardianEmail) {
      visibleCheckbox.checked = useGuardianEmail;
    }
  }
  
  /**
   * Copy guardian's address fields to dependent fields
   */
  copyGuardianAddressInfo() {
    const guardianFields = {
      address1: document.querySelector('input[name="guardian_attributes[physical_address_1]"]'),
      address2: document.querySelector('input[name="guardian_attributes[physical_address_2]"]'),
      city: document.querySelector('input[name="guardian_attributes[city]"]'),
      state: document.querySelector('input[name="guardian_attributes[state]"]'),
      zip: document.querySelector('input[name="guardian_attributes[zip_code]"]')
    };
    
    const dependentFields = {
      address1: document.querySelector('input[name="dependent_attributes[physical_address_1]"]'),
      address2: document.querySelector('input[name="dependent_attributes[physical_address_2]"]'),
      city: document.querySelector('input[name="dependent_attributes[city]"]'),
      state: document.querySelector('input[name="dependent_attributes[state]"]'),
      zip: document.querySelector('input[name="dependent_attributes[zip_code]"]')
    };
    
    // Copy values if both fields exist
    if (guardianFields.address1 && dependentFields.address1) 
      dependentFields.address1.value = guardianFields.address1.value || '';
      
    if (guardianFields.address2 && dependentFields.address2)
      dependentFields.address2.value = guardianFields.address2.value || '';
      
    if (guardianFields.city && dependentFields.city)
      dependentFields.city.value = guardianFields.city.value || '';
      
    if (guardianFields.state && dependentFields.state)
      dependentFields.state.value = guardianFields.state.value || 'MD';
      
    if (guardianFields.zip && dependentFields.zip)
      dependentFields.zip.value = guardianFields.zip.value || '';
  }
  
  /**
   * Copy guardian's email to dependent email field
   */
  copyGuardianEmail() {
    const guardianEmailField = document.querySelector('input[name="guardian_attributes[email]"]');
    const dependentEmailField = document.querySelector('input[name="dependent_attributes[email]"]');
    
    // Only attempt to copy if both fields exist
    if (!guardianEmailField || !dependentEmailField) return;
    
    // Copy email if guardian email is available, otherwise clear
    if (guardianEmailField.value) {
      dependentEmailField.value = guardianEmailField.value;
    } else {
      // Clear the field to ensure the server knows to use guardian's email
      dependentEmailField.value = '';
    }
  }
  
  /**
   * Handle applicant type change event from parent controller
   * @param {CustomEvent} event The change:applicant-type custom event
   */
  handleApplicantTypeChange(event) {
    // Store event data for debounced execution
    this._pendingEvent = event;
    this.debouncedApplicantTypeChange();
  }

  /**
   * Execute the applicant type change logic (debounced)
   */
  executeApplicantTypeChange() {
    try {
      if (!this._pendingEvent) return;
      
      const isForDependent = this._pendingEvent.detail.isDependentSelected;
      
      // Use utility to handle visibility of this controller's element
      setVisible(this.element, isForDependent);
      
      // Use utility to handle relationship type required state
      if (this.hasRelationshipTypeTarget) {
        setVisible(this.relationshipTypeTarget, true, { required: isForDependent });
      }
      
      // Re-apply email and address checkbox states when applicant type changes
      // Only if we're showing the dependent fields
      if (isForDependent) {
        if (this.hasSameEmailCheckboxTarget) {
          this.toggleEmailField({ target: this.sameEmailCheckboxTarget });
        }
        
        if (this.hasSameAddressCheckboxTarget) {
          this.toggleContactFields({ target: this.sameAddressCheckboxTarget });
        }
      }
      
    } catch (error) {
      console.error("DependentFieldsController: Error in executeApplicantTypeChange:", error);
    }
  }
}
