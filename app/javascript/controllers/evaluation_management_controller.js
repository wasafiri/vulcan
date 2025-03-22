import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "statusSelect", 
    "completionFields",
    "rescheduleSection"
  ]

  connect() {
    this.toggleFieldsBasedOnStatus()
  }

  toggleFieldsBasedOnStatus() {
    const selectedStatus = this.statusSelectTarget.value

    if (this.hasCompletionFieldsTarget) {
      if (selectedStatus === "completed") {
        this.completionFieldsTarget.classList.remove("hidden")
        this.setRequiredAttributes(true)
      } else {
        this.completionFieldsTarget.classList.add("hidden")
        this.setRequiredAttributes(false)
      }
    }
  }

  setRequiredAttributes(required) {
    this.completionFieldsTarget.querySelectorAll("[data-completion-required]").forEach(element => {
      if (required) {
        element.setAttribute("required", "")
      } else {
        element.removeAttribute("required")
      }
    })
  }
}
