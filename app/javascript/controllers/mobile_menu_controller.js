import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu", "button" ]
  
  toggle() {
    this.menuTarget.classList.toggle("hidden")
    const isExpanded = this.buttonTarget.getAttribute("aria-expanded") === "true"
    this.buttonTarget.setAttribute("aria-expanded", !isExpanded)
  }
}