import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]

  connect() {
    this.toggleIcon = this.element.querySelector("[data-action='visibility#toggle']")
  }

  toggle() {
    const field = this.fieldTarget
    const type = field.type === "password" ? "text" : "password"
    field.type = type
    
    // Update button aria-pressed state
    this.toggleIcon.setAttribute("aria-pressed", type === "text")
  }
}