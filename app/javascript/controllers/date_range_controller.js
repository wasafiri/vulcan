import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "customRange" ]

  connect() {
    this.toggleCustomRange({ target: { value: this.element.querySelector("select").value } })
  }

  toggleCustomRange(event) {
    const isCustom = event.target.value === "custom"
    this.customRangeTargets.forEach(element => {
      element.style.display = isCustom ? "block" : "none"
      
      // Make fields required only when visible
      const input = element.querySelector("input")
      if (input) {
        if (isCustom) {
          input.setAttribute("required", "")
        } else {
          input.removeAttribute("required")
        }
      }
    })
  }
}
