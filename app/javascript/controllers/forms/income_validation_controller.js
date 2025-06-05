import { Controller } from "@hotwired/stimulus"
import { railsRequest } from "../../services/rails_request"
import { applyTargetSafety } from "../../mixins/target_safety"
import { setVisible } from "../../utils/visibility"

/**
 * Income Validation Controller
 * 
 * Validates that annual income is within FPL (Federal Poverty Level) thresholds
 * for the given household size. Shows warnings and disables submission if income
 * exceeds the threshold.
 */
class IncomeValidationController extends Controller {
  static targets = [
    "householdSize", "annualIncome", "warningContainer", "submitButton"
  ]

  static outlets = ["flash"] // Declare flash outlet
  static values = {
    fplUrl: String,  // Rails-Native: URL provided via data attribute
    modifier: { type: Number, default: 200 } // Default to 200% of FPL
  }

  connect() {
    this.fplThresholds = {}
    
    // Request key for tracking
    this.requestKey = `income-validation-${this.identifier}-${Date.now()}`
    
    // Bind method for event listener cleanup
    this._validate = this.validateIncomeThreshold.bind(this)
    
    this.setupEventListeners()
    
    // Fetch FPL data and validate initial state
    this.fetchFplThresholds()
  }

  disconnect() {
    // Cancel any pending request
    railsRequest.cancel(this.requestKey)
    
    this.teardownEventListeners()
  }

  setupEventListeners() {
    this.withTarget('householdSize', (target) => {
      target.addEventListener("input", this._validate)
      target.addEventListener("change", this._validate)
    })
    
    this.withTarget('annualIncome', (target) => {
      target.addEventListener("input", this._validate)
      target.addEventListener("change", this._validate)
    })
  }

  teardownEventListeners() {
    this.withTarget('householdSize', (target) => {
      target.removeEventListener("input", this._validate)
      target.removeEventListener("change", this._validate)
    })
    
    this.withTarget('annualIncome', (target) => {
      target.removeEventListener("input", this._validate)
      target.removeEventListener("change", this._validate)
    })
  }

  // Rails 8 @rails/request.js FPL threshold loading
  async fetchFplThresholds() {
    // Rails-Native Pattern: Require URL to be provided via Stimulus values
    if (!this.hasFplUrlValue) {
      console.error("Income validation requires fplUrl value to be provided")
      this.handleFetchError(new Error("FPL URL not configured"))
      return
    }

    try {
      // Use centralized rails request service
      const result = await railsRequest.perform({
        method: 'get',
        url: this.fplUrlValue,
        key: this.requestKey
      })

      if (result.success) {
        const data = result.data
        
        if (process.env.NODE_ENV !== 'production') {
          console.log("FPL thresholds loaded successfully", data)
        }
        
        // Store the FPL data
        this.fplThresholds = data.thresholds || {}
        this.modifierValue = data.modifier || this.modifierValue
        
        // Re-run validation with new data
        this.validateIncomeThreshold()
      }

    } catch (error) {
      console.error("FPL thresholds loading failed", error)
      this.handleFetchError(error)
    }
  }

  validateIncomeThreshold() {
    const size = this.getHouseholdSize()
    const income = this.getAnnualIncome()
    
    // Skip validation if inputs are invalid
    if (size < 1 || income < 1) {
      this.clearValidationState()
      return
    }

    const threshold = this.calculateThreshold(size)
    const exceedsThreshold = income > threshold
    
    this.updateValidationUI(exceedsThreshold, threshold)
    
    // Dispatch custom event for other controllers to listen to
    this.dispatch("validated", { 
      detail: { 
        exceedsThreshold, 
        income, 
        threshold, 
        householdSize: size 
      } 
    })
  }

  getHouseholdSize() {
    return this.withTarget('householdSize', (target) => {
      return parseInt(target.value, 10) || 0
    }, 0)
  }

  getAnnualIncome() {
    return this.withTarget('annualIncome', (target) => {
      // Handle both formatted and raw input values
      const value = target.value
      const rawValue = target.dataset.rawValue
      
      if (rawValue) {
        return parseFloat(rawValue) || 0
      }
      
      return parseFloat(value.replace(/[^\d.-]/g, '')) || 0
    }, 0)
  }

  calculateThreshold(householdSize) {
    const baseFpl = this.fplThresholds[Math.min(householdSize, 8)] || 0
    return baseFpl * (this.modifierValue / 100)
  }

  updateValidationUI(exceedsThreshold, threshold) {
    this.updateWarningDisplay(exceedsThreshold, threshold)
    this.updateSubmitButton(exceedsThreshold)
  }

  updateWarningDisplay(exceedsThreshold, threshold) {
    this.withTarget('warningContainer', (target) => {
      if (exceedsThreshold) {
        this.showWarning(target, threshold)
      } else {
        this.hideWarning(target)
      }
    })
  }

  showWarning(target, threshold) {
    target.innerHTML = this.buildWarningHTML(threshold)
    setVisible(target, true)
    target.setAttribute("role", "alert")
  }

  hideWarning(target) {
    setVisible(target, false)
    target.removeAttribute("role")
  }

  buildWarningHTML(threshold) {
    const formattedThreshold = threshold.toLocaleString('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })

    return `
      <div class="bg-red-600 border-2 border-red-700 text-white font-bold p-4 rounded-md">
        <h3 class="font-bold text-lg">Income Exceeds Threshold</h3>
        <p>Your annual income exceeds the maximum threshold of ${formattedThreshold} for your household size.</p>
        <p>Applications with income above the threshold are not eligible for this program.</p>
      </div>
    `
  }

  updateSubmitButton(exceedsThreshold) {
    this.withTarget('submitButton', (target) => {
      target.disabled = exceedsThreshold
      
      if (exceedsThreshold) {
        target.classList.add("opacity-50", "cursor-not-allowed")
        target.setAttribute("disabled", "disabled")
      } else {
        target.classList.remove("opacity-50", "cursor-not-allowed")
        target.removeAttribute("disabled")
      }
    })
  }

  clearValidationState() {
    this.withTarget('warningContainer', (target) => this.hideWarning(target))
    this.updateSubmitButton(false)
  }

  handleFetchError(error) {
    console.error("FPL threshold fetch failed:", error)
    
    this.withTarget('warningContainer', (target) => {
      target.innerHTML = `
        <div class="bg-yellow-100 border border-yellow-400 text-yellow-700 p-4 rounded">
          <p>Unable to load income thresholds. Please refresh the page and try again.</p>
        </div>
      `
      setVisible(target, true)
    })

    if (this.hasFlashOutlet) {
      this.flashOutlet.showError("Failed to load income thresholds. Please refresh the page.")
    }
  }

  // Action methods for manual triggering
  validateAction() {
    this.validateIncomeThreshold()
  }

  refreshThresholdsAction() {
    this.fetchFplThresholds()
  }
}

// Apply target safety mixin
applyTargetSafety(IncomeValidationController)

export default IncomeValidationController
