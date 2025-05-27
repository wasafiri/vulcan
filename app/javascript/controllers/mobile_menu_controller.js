import { Controller } from "@hotwired/stimulus"
import { setVisible } from "../utils/visibility"

export default class extends Controller {
  static targets = [ "menu", "button" ]
  
  toggle() {
    // Guard against missing targets
    if (!this.hasMenuTarget || !this.hasButtonTarget) return
    
    const isCurrentlyHidden = this.menuTarget.classList.contains("hidden")
    setVisible(this.menuTarget, isCurrentlyHidden)
    const isExpanded = this.buttonTarget.getAttribute("aria-expanded") === "true"
    this.buttonTarget.setAttribute("aria-expanded", !isExpanded)
  }
}
