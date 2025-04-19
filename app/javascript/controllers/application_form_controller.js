import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    // Override via data‑controller‑fpl-url‑value if you ever need to.
    fplUrl: String
  }

  static targets = [
    "householdSize",
    "annualIncome",
    "submitButton"
  ]

  connect() {
    // --- state ---
    this.fplThresholds = {}
    this.fplModifier   = 400
    this._validate     = this.validateIncomeThreshold.bind(this)
    this.fetchController = null

    // --- fetch & warn element ---
    this.fetchFplThresholds()
    this.addIncomeThresholdWarning()

    // --- wire up live validation ---
    this.householdSizeTarget.addEventListener("input", this._validate)
    this.annualIncomeTarget.addEventListener("input", this._validate)
  }

  disconnect() {
    // Abort any in‑flight fetch
    if (this.fetchController) {
      this.fetchController.abort()
    }
    // Clean up listeners
    this.householdSizeTarget.removeEventListener("input", this._validate)
    this.annualIncomeTarget.removeEventListener("input", this._validate)
  }

  fetchFplThresholds() {
    const url = this.hasFplUrlValue
      ? this.fplUrlValue
      : "/constituent_portal/applications/fpl_thresholds"

    // AbortController lets us cancel if the controller disconnects
    this.fetchController = new AbortController()

    fetch(url, { signal: this.fetchController.signal })
      .then(res => res.json())
      .then(data => {
        this.fplThresholds = data.thresholds || {}
        this.fplModifier   = data.modifier  || this.fplModifier
        // Re‑run validator in case inputs already have values
        this.validateIncomeThreshold()
      })
      .catch(err => {
        if (err.name === "AbortError") return
        console.error("Failed to load FPL thresholds:", err)
      })
  }

  addIncomeThresholdWarning() {
    // Avoid dupes if Stimulus hot‑reloads or controller reconnects
    if (document.getElementById("income-threshold-warning")) return

    const warning = document.createElement("div")
    warning.id    = "income-threshold-warning"
    warning.className =
      "hidden bg-red-100 border border-red-400 text-red-700 p-4 rounded mb-4"
    warning.setAttribute("role", "alert")
    warning.innerHTML = `
      <h3 class="font-medium">Income Exceeds Threshold</h3>
      <p>Your annual income exceeds the maximum threshold for your household size.</p>
      <p>Applications with income above the threshold are not eligible for this program.</p>
    `

    // Insert right after #main-content if present, else fallback to top of form
    const main = document.getElementById("main-content")
    if (main && main.parentNode) {
      main.parentNode.insertBefore(warning, main.nextSibling)
    } else {
      const form = this.element.querySelector("form") || document.body
      form.insertBefore(warning, form.firstChild)
    }

    // Keep a ref so we don't querySelector each time
    this.warningElement = warning
  }

  validateIncomeThreshold() {
    const size  = parseInt(this.householdSizeTarget.value, 10) || 0
    const income = parseFloat(this.annualIncomeTarget.value)   || 0
    const warning = this.warningElement
    const btn     = this.submitButtonTarget

    // If we don't have bona fide inputs yet, just clear state
    if (size < 1 || income < 1) {
      warning.classList.add("hidden")
      btn.disabled = false
      btn.classList.remove("opacity-50", "cursor-not-allowed")
      return
    }

    const baseFpl = this.fplThresholds[Math.min(size, 8)] || 0
    const threshold = baseFpl * (this.fplModifier / 100)

    if (income > threshold) {
      warning.classList.remove("hidden")
      btn.disabled = true
      btn.classList.add("opacity-50", "cursor-not-allowed")
    } else {
      warning.classList.add("hidden")
      btn.disabled = false
      btn.classList.remove("opacity-50", "cursor-not-allowed")
    }
  }
}
