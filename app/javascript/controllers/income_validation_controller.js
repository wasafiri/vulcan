import { Controller } from "@hotwired/stimulus"
import { setVisible } from "../utils/visibility"

/**
 * Validates household income against Federal Poverty Level (FPL) thresholds and shows/hides warnings.
 */
export default class extends Controller {
  static targets = [
    "householdSize",
    "annualIncome", 
    "submitButton",
    "warningContainer"
  ]

  static values = {
    fplUrl: String,
    modifier: { type: Number, default: 400 }
  }

  connect() {
    this.fplThresholds = {}
    this.fetchController = null
    
    // Bind methods to preserve context
    this._validate = this.validateIncomeThreshold.bind(this)
    
    // Set up event listeners
    this.setupEventListeners()
    
    // Fetch FPL data and validate initial state
    this.fetchFplThresholds()
  }

  disconnect() {
    this.teardownEventListeners()
    if (this.fetchController) {
      this.fetchController.abort()
    }
  }

  setupEventListeners() {
    if (this.hasHouseholdSizeTarget) {
      this.householdSizeTarget.addEventListener("input", this._validate)
      this.householdSizeTarget.addEventListener("change", this._validate)
    }
    
    if (this.hasAnnualIncomeTarget) {
      this.annualIncomeTarget.addEventListener("input", this._validate)
      this.annualIncomeTarget.addEventListener("change", this._validate)
    }
  }

  teardownEventListeners() {
    if (this.hasHouseholdSizeTarget) {
      this.householdSizeTarget.removeEventListener("input", this._validate)
      this.householdSizeTarget.removeEventListener("change", this._validate)
    }
    
    if (this.hasAnnualIncomeTarget) {
      this.annualIncomeTarget.removeEventListener("input", this._validate)
      this.annualIncomeTarget.removeEventListener("change", this._validate)
    }
  }

  async fetchFplThresholds() {
    const url = this.hasFplUrlValue 
      ? this.fplUrlValue 
      : "/constituent_portal/applications/fpl_thresholds"

    this.fetchController = new AbortController()

    try {
      const response = await fetch(url, { 
        signal: this.fetchController.signal 
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      this.fplThresholds = data.thresholds || {}
      this.modifierValue = data.modifier || this.modifierValue
      
      // Re-run validation with new data
      this.validateIncomeThreshold()
      
    } catch (error) {
      if (error.name === "AbortError") return
      console.error("Failed to load FPL thresholds:", error)
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
    if (!this.hasHouseholdSizeTarget) return 0
    return parseInt(this.householdSizeTarget.value, 10) || 0
  }

  getAnnualIncome() {
    if (!this.hasAnnualIncomeTarget) return 0
    
    // Handle both formatted and raw input values
    const value = this.annualIncomeTarget.value
    const rawValue = this.annualIncomeTarget.dataset.rawValue
    
    if (rawValue) {
      return parseFloat(rawValue) || 0
    }
    
    return parseFloat(value.replace(/[^\d.-]/g, '')) || 0
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
    if (!this.hasWarningContainerTarget) return
    
    if (exceedsThreshold) {
      this.showWarning(threshold)
    } else {
      this.hideWarning()
    }
  }

  showWarning(threshold) {
    this.warningContainerTarget.innerHTML = this.buildWarningHTML(threshold)
    setVisible(this.warningContainerTarget, true)
    this.warningContainerTarget.setAttribute("role", "alert")
  }

  hideWarning() {
    setVisible(this.warningContainerTarget, false)
    this.warningContainerTarget.removeAttribute("role")
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
    if (!this.hasSubmitButtonTarget) return
    
    this.submitButtonTarget.disabled = exceedsThreshold
    
    if (exceedsThreshold) {
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
      this.submitButtonTarget.setAttribute("disabled", "disabled")
    } else {
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
      this.submitButtonTarget.removeAttribute("disabled")
    }
  }

  clearValidationState() {
    this.hideWarning()
    this.updateSubmitButton(false)
  }

  handleFetchError(error) {
    console.error("FPL threshold fetch failed:", error)
    
    if (this.hasWarningContainerTarget) {
      this.warningContainerTarget.innerHTML = `
        <div class="bg-yellow-100 border border-yellow-400 text-yellow-700 p-4 rounded">
          <p>Unable to load income thresholds. Please refresh the page and try again.</p>
        </div>
      `
      setVisible(this.warningContainerTarget, true)
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
