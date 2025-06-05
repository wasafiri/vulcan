import { Controller } from "@hotwired/stimulus"
import { applyTargetSafety } from "../../mixins/target_safety"
import { setVisible } from "../../utils/visibility"
import { createFormChangeDebounce } from "../../utils/debounce"

/**
 * Controller for managing dependent-related fields
 * 
 * Responsible for toggling dependent contact information visibility and handling
 * the "Same as Guardian's" functionality for both address and email.
 */
class DependentFieldsController extends Controller {
  static targets = [
    "fields", 
    "addressFields", 
    "sameAddressCheckbox", 
    "sameEmailCheckbox", 
    "relationshipType", 
    "emailFieldContainer",
    "dependentEmail",
    "guardianEmail", 
    "guardianAddress1",
    "guardianAddress2", 
    "guardianCity",
    "guardianState",
    "guardianZip",
    "dependentAddress1",
    "dependentAddress2",
    "dependentCity", 
    "dependentState",
    "dependentZip",
    "useGuardianEmailInput"
  ]
  
  static outlets = ["flash"] // Declare flash outlet
  static values = {
    copyFromGuardian: Boolean
  }

  connect() {
    // Store bound method reference for proper cleanup
    this._boundHandleApplicantTypeChange = this.handleApplicantTypeChange.bind(this)
    
    // Set up debounced applicant type change handler
    this.debouncedApplicantTypeChange = createFormChangeDebounce(() => this.executeApplicantTypeChange())
    
    // Set initial state based on checkbox if available - use target safety
    this.withTarget('sameAddressCheckbox', (checkbox) => {
      this.toggleContactFields({ target: checkbox })
    })
    
    // Set initial state for email checkbox - use target safety
    this.withTarget('sameEmailCheckbox', (checkbox) => {
      this.toggleEmailField({ target: checkbox })
    })
    
    // Listen for applicant-type change events from ApplicantTypeController
    this.formElement = this.element.closest("form")
    if (this.formElement) {
      this.formElement.addEventListener(
        "applicant-type:applicantTypeChanged", 
        this._boundHandleApplicantTypeChange
      )
    }
  }
  
  disconnect() {
    // Clean up event listeners
    if (this.formElement && this._boundHandleApplicantTypeChange) {
      this.formElement.removeEventListener(
        "applicant-type:applicantTypeChanged", 
        this._boundHandleApplicantTypeChange
      )
    }
    
    // Clean up debounced function
    this.debouncedApplicantTypeChange?.cancel()
  }
  
  /**
   * Toggle contact fields based on "Same as Guardian's Address" checkbox
   * @param {Event} event The change event from the checkbox
   */
  toggleContactFields(event) {
    if (!this.hasRequiredTargets('addressFields')) {
      return
    }
    
    const useGuardianContact = event.target.checked
    this.copyFromGuardianValue = useGuardianContact
    
    // Use utility to toggle visibility and required state for the container
    setVisible(this.addressFieldsTarget, !useGuardianContact)
    
    // Handle required attributes for individual input fields within the container
    const inputFields = this.addressFieldsTarget.querySelectorAll('input')
    inputFields.forEach(field => {
      setVisible(field, !useGuardianContact, { required: !useGuardianContact })
    })
    
    // Copy guardian contact info if needed
    if (useGuardianContact) {
      this.copyGuardianAddressInfo()
    }
  }
  
  /**
   * Toggle dependent email field based on "Use Guardian's Email" checkbox
   * @param {Event} event The change event from the checkbox
   */
  toggleEmailField(event) {
    const useGuardianEmail = event.target.checked;
    
    if (!this.hasDependentEmailTarget) {
      console.warn("Missing dependentEmail target - check HTML structure");
      return;
    }
    
    // Update the hidden input value
    this.updateUseGuardianEmailInput(useGuardianEmail);
    
    // Use utility to handle email field visibility and required state
    setVisible(this.dependentEmailTarget, !useGuardianEmail, { required: !useGuardianEmail });
    
    // Handle email field container visibility if available
    if (this.hasEmailFieldContainerTarget) {
      setVisible(this.emailFieldContainerTarget, !useGuardianEmail);
    }
    
    // Copy guardian's email if needed
    if (useGuardianEmail) {
      this.copyGuardianEmail();
    }
  }
  
  /**
   * Update the hidden form field to indicate whether to use guardian's email
   * @param {boolean} useGuardianEmail Whether to use guardian's email
   */
  updateUseGuardianEmailInput(useGuardianEmail) {
    const visibleCheckbox = this.hasSameEmailCheckboxTarget 
      ? this.sameEmailCheckboxTarget 
      : (this.hasUseGuardianEmailInputTarget ? this.useGuardianEmailInputTarget : null);
    
    // Ensure the checkbox value matches our parameter
    if (visibleCheckbox && visibleCheckbox.checked !== useGuardianEmail) {
      visibleCheckbox.checked = useGuardianEmail;
    }
  }
  
  /**
   * Copy guardian's address fields to dependent fields
   */
  copyGuardianAddressInfo() {
    const guardianTargetsAvailable = this.hasGuardianAddress1Target && 
                                   this.hasGuardianAddress2Target && 
                                   this.hasGuardianCityTarget && 
                                   this.hasGuardianStateTarget && 
                                   this.hasGuardianZipTarget;
                                   
    const dependentTargetsAvailable = this.hasDependentAddress1Target && 
                                    this.hasDependentAddress2Target && 
                                    this.hasDependentCityTarget && 
                                    this.hasDependentStateTarget && 
                                    this.hasDependentZipTarget;
    
    if (!guardianTargetsAvailable || !dependentTargetsAvailable) {
      console.warn("Missing address field targets - check HTML structure");
      return;
    }
    
    // Copy values using targets
    this.dependentAddress1Target.value = this.guardianAddress1Target.value || '';
    this.dependentAddress2Target.value = this.guardianAddress2Target.value || '';
    this.dependentCityTarget.value = this.guardianCityTarget.value || '';
    this.dependentStateTarget.value = this.guardianStateTarget.value || 'MD';
    this.dependentZipTarget.value = this.guardianZipTarget.value || '';
  }
  
  /**
   * Copy guardian's email to dependent email field
   */
  copyGuardianEmail() {
    if (!this.hasGuardianEmailTarget || !this.hasDependentEmailTarget) {
      console.warn("Missing email field targets - check HTML structure");
      return;
    }
    
    // Copy email if guardian email is available, otherwise clear
    if (this.guardianEmailTarget.value) {
      this.dependentEmailTarget.value = this.guardianEmailTarget.value;
    } else {
      // Clear the field to ensure the server knows to use guardian's email
      this.dependentEmailTarget.value = '';
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
      if (this.hasFlashOutlet) {
        this.flashOutlet.showError("An error occurred while updating dependent fields. Please try again.");
      }
    }
  }
}

// Apply target safety mixin
applyTargetSafety(DependentFieldsController)

export default DependentFieldsController
