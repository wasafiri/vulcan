import { Controller } from "@hotwired/stimulus";
import { setVisible } from "../utils/visibility";

export default class extends Controller {
  static targets = [
    "householdSize", // Assuming these are still relevant for income validation
    "annualIncome",  // Assuming these are still relevant for income validation
    "submitButton",
    "rejectionModal",
    "incomeThresholdWarning",
    "incomeThresholdBadge" // This was to be removed from view, but target kept for now if logic remains
  ];

  connect() {
    console.log("PaperApplicationController connected");
    // Store bound method references for proper cleanup
    this._boundValidateIncomeThreshold = this.validateIncomeThreshold.bind(this)
    this.initializeIncomeValidation();
  }

  disconnect() {
    // Clean up event listeners
    if (this.hasHouseholdSizeTarget) {
      this.householdSizeTarget.removeEventListener('change', this._boundValidateIncomeThreshold);
    }
    if (this.hasAnnualIncomeTarget) {
      this.annualIncomeTarget.removeEventListener('change', this._boundValidateIncomeThreshold);
    }
  }

  /**
 * Set up income threshold validation
 */
  initializeIncomeValidation() {
    // Find the income and household size fields
    if (this.hasHouseholdSizeTarget && this.hasAnnualIncomeTarget) {
      this.householdSizeTarget.addEventListener('change', this._boundValidateIncomeThreshold);
      this.annualIncomeTarget.addEventListener('change', this._boundValidateIncomeThreshold);
      // Initial validation on connect if values are present
      this.validateIncomeThreshold();
    }
  }

  /**
 * Validate the income threshold based on household size and income
 */
  validateIncomeThreshold() {
    if (!this.hasHouseholdSizeTarget || !this.hasAnnualIncomeTarget) return;

    const householdSize = parseInt(this.householdSizeTarget.value, 10) || 0;
    const annualIncome = parseFloat(this.annualIncomeTarget.value) || 0;

    // Don't validate if either is not set or invalid
    if (householdSize <= 0 || annualIncome <= 0) {
      // Reset UI if inputs are cleared or invalid
      this.updateIncomeThresholdUI(false, 0);
      return;
    }

    // Fetch FPL data - In a real app, this might come from an API endpoint or data attributes
    // For now, using the placeholder from the original controller.
    // Consider fetching /admin/paper_applications/fpl_thresholds if this needs to be dynamic
    fetch('/admin/paper_applications/fpl_thresholds')
      .then(response => {
        if (!response.ok) throw new Error('Network response was not ok');
        return response.json();
      })
      .then(data => {
        const baseThreshold = data.thresholds[householdSize] || data.thresholds[Object.keys(data.thresholds).pop()]; // Fallback
        const modifierPercentage = data.modifier;

        if (baseThreshold === undefined || modifierPercentage === undefined) {
          console.error("FPL data missing for household size or modifier.");
          this.updateIncomeThresholdUI(false, 0); // Reset UI on error
          return;
        }

        const maxIncomeThreshold = baseThreshold * (modifierPercentage / 100);
        const exceedsThreshold = annualIncome > maxIncomeThreshold;
        this.updateIncomeThresholdUI(exceedsThreshold, maxIncomeThreshold);
      })
      .catch(error => {
        console.error('Error fetching FPL thresholds:', error);
        this.updateIncomeThresholdUI(false, 0); // Reset UI on error
        // Optionally show an error message to the user
        if (this.hasIncomeThresholdWarningTarget) {
            this.incomeThresholdWarningTarget.innerHTML = '<p class="text-red-700">Could not verify income threshold. Please try again.</p>';
            setVisible(this.incomeThresholdWarningTarget, true);
        }
      });
  }

  /**
 * Update the UI for income threshold validation
 * @param {boolean} exceedsThreshold Whether income exceeds threshold
 * @param {number} maxThreshold The maximum threshold amount (currently unused in UI update)
 */
  updateIncomeThresholdUI(exceedsThreshold, _maxThreshold) {
    if (this.hasIncomeThresholdWarningTarget) {
      setVisible(this.incomeThresholdWarningTarget, exceedsThreshold);
    }
    // The incomeThresholdBadgeTarget was removed from the view in the proposal.
    // If it's truly gone, this line can be removed. Keeping for now.
    if (this.hasIncomeThresholdBadgeTarget) {
      setVisible(this.incomeThresholdBadgeTarget, exceedsThreshold);
    }

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

    const rejectionButton = document.getElementById('rejection-button'); // Still using getElementById as per original
    if (rejectionButton) {
      setVisible(rejectionButton, exceedsThreshold);
    }
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
}
