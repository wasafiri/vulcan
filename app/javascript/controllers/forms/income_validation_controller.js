import { Controller } from "@hotwired/stimulus"
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
    fplThresholds: String,  // JSON string of FPL thresholds
    modifier: Number // FPL modifier percentage from policy
  }

  connect() {
    // Parse FPL thresholds from server-rendered data
    try {
      this.fplThresholds = JSON.parse(this.fplThresholdsValue)
    } catch (error) {
      console.error("Failed to parse FPL thresholds:", error)
      this.fplThresholds = {}
    }
    
    // Bind method for event listener cleanup
    this._validate = this.validateIncomeThreshold.bind(this)

    this.setupEventListeners()

    // Mark as loaded and validate initial state
    this.element.dataset.fplLoaded = "true"
    this.element.classList.add("fpl-data-loaded")
    this.dispatch("fpl-data-loaded")
    this.validateIncomeThreshold()
  }

  disconnect() {
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
    const size = Math.min(householdSize, 8)
    
    // Use server-rendered data with fallback to prevent failures
    let baseFpl = 0
    if (this.fplThresholds && typeof this.fplThresholds === 'object') {
      baseFpl = this.fplThresholds[size.toString()] || this.fplThresholds[size] || 0
    }
    
    // Fallback to hardcoded values if server data parsing fails
    if (!baseFpl) {
      const fallbackFpl = {
        1: 15650, 2: 21150, 3: 26650, 4: 32150,
        5: 37650, 6: 43150, 7: 48650, 8: 54150
      }
      baseFpl = fallbackFpl[size] || 0
    }
    
    // Use Stimulus value (automatically parsed from data-income-validation-modifier-value)
    let modifier = this.modifierValue || 400 // Use Stimulus parsed value with fallback
    
    return baseFpl * (modifier / 100)
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
      console.log(`Income validation: Setting button disabled = ${exceedsThreshold}`)
      target.disabled = exceedsThreshold

      if (exceedsThreshold) {
        target.classList.add("opacity-50", "cursor-not-allowed")
        target.setAttribute("disabled", "disabled")
      } else {
        target.classList.remove("opacity-50", "cursor-not-allowed")
        target.removeAttribute("disabled")
      }
    })
    
    // Debug: Check if target was found
    const hasTarget = this.hasSubmitButtonTarget
    console.log(`Income validation: hasSubmitButtonTarget = ${hasTarget}`)
  }

  clearValidationState() {
    this.withTarget('warningContainer', (target) => this.hideWarning(target))
    this.updateSubmitButton(false)
  }


  // Action methods for manual triggering
  validateAction() {
    this.validateIncomeThreshold()
  }

}

// Apply target safety mixin
applyTargetSafety(IncomeValidationController)

export default IncomeValidationController
