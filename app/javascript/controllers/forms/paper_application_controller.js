import { Controller } from "@hotwired/stimulus";
import { setVisible } from "../../utils/visibility";

export default class extends Controller {
  static targets = [
    "submitButton",
    "rejectionModal",
    "rejectionButton"
  ];

  connect() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("PaperApplicationController connected");
    }

    // Listen for income validation events from income_validation_controller
    this._boundHandleIncomeValidation = this.handleIncomeValidation.bind(this);
    this.element.addEventListener('income-validation:validated', this._boundHandleIncomeValidation);
  }

  disconnect() {
    // Clean up event listeners
    if (this._boundHandleIncomeValidation) {
      this.element.removeEventListener('income-validation:validated', this._boundHandleIncomeValidation);
    }
  }

  /**
   * Handle income validation results from income_validation_controller
   * @param {CustomEvent} event The validation event with details about threshold status
   */
  handleIncomeValidation(event) {
    const { exceedsThreshold } = event.detail;
    this.updateSubmissionUI(exceedsThreshold);
  }

  /**
   * Update submission UI based on income threshold validation
   * @param {boolean} exceedsThreshold Whether income exceeds threshold
   */
  updateSubmissionUI(exceedsThreshold) {
    if (this.hasSubmitButtonTarget) {
      // Setting the property AND the attribute for the selector to match
      this.submitButtonTarget.disabled = exceedsThreshold;

      // This is critical: For the CSS selector input[type=submit][disabled] to match,
      // we need to set the HTML attribute, not just the JS property
      if (exceedsThreshold) {
        this.submitButtonTarget.setAttribute('disabled', 'disabled');
      } else {
        this.submitButtonTarget.removeAttribute('disabled');
      }
    }

    if (this.hasRejectionButtonTarget) {
      setVisible(this.rejectionButtonTarget, exceedsThreshold);
    } else if (exceedsThreshold) {
      console.warn("Missing rejectionButton target - check HTML structure");
    }
  }

  /**
   * Temporary method to prevent errors - this functionality should be handled by income-validation controller
   * TODO: Replace with proper income-validation controller setup
   */
  validateIncomeThreshold() {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('validateIncomeThreshold called on paper-application controller - this should be handled by income-validation controller');
    }
    // For now, just prevent the error - the income validation should be handled elsewhere
  }

  /* Modal helpers */
  openRejectionModal() {
    if (this.hasRejectionModalTarget) {
      setVisible(this.rejectionModalTarget, true);
    }
  }

  closeRejectionModal() {
    if (this.hasRejectionModalTarget) {
      setVisible(this.rejectionModalTarget, false);
    }
  }


  // Main rejection method - implement form submission
  rejectForIncome() {
    console.log('rejectForIncome called');
    
    // Get the main form element (the form this controller is attached to)
    const form = this.element.querySelector('form') || this.element;
    console.log('Form found:', form);
    
    if (form) {
      // Set the rejection endpoint
      form.action = '/admin/paper_applications/reject_for_income';
      form.method = 'POST';
      
      console.log('New action:', form.action);
      console.log('Form method:', form.method);
      
      // Submit the form
      form.submit();
    } else {
      console.error('No form found in paper application controller element');
    }
  }
}
