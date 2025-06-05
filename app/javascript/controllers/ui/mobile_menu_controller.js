import { Controller } from "@hotwired/stimulus"
import { applyTargetSafety } from "../../mixins/target_safety"
import { setVisible } from "../../utils/visibility"

class MobileMenuController extends Controller {
  static targets = [ "menu", "button" ]
  
  toggle() {
    // Use target safety to check for required targets
    if (!this.hasRequiredTargets('menu', 'button')) {
      return;
    }
    
    const isCurrentlyHidden = this.menuTarget.classList.contains("hidden")
    setVisible(this.menuTarget, isCurrentlyHidden)
    
    const isExpanded = this.buttonTarget.getAttribute("aria-expanded") === "true"
    this.buttonTarget.setAttribute("aria-expanded", !isExpanded)
  }
}

// Apply target safety mixin
applyTargetSafety(MobileMenuController)

export default MobileMenuController
