import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chart", "button"]

  connect() {
    // Initialize button state
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute('aria-expanded', 'false')
      this.buttonTarget.setAttribute('aria-controls', 'monthly-totals-chart')
    }
  }

  toggle() {
    const isHidden = this.chartTarget.classList.contains('hidden')
    this.chartTarget.classList.toggle('hidden')
    
    // Update button state for accessibility
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute('aria-expanded', isHidden ? 'true' : 'false')
      this.buttonTarget.textContent = isHidden ? 'Hide Chart' : 'Show Chart'
    }
  }
}
