import { Controller } from "@hotwired/stimulus"

// This controller handles the toggling of custom date range fields
// When "Custom Range" is selected in the date range dropdown
export default class extends Controller {
  static targets = ["customRange"]

  connect() {
    // Check if custom range is already selected on page load
    this.toggleCustomRange({ target: this.element.querySelector('[name="date_range"]') })
  }

  toggleCustomRange(event) {
    const selectElement = event.target
    const isCustomRange = selectElement && selectElement.value === "custom"
    
    this.customRangeTargets.forEach(element => {
      element.style.display = isCustomRange ? "" : "none"
    })
  }
}
