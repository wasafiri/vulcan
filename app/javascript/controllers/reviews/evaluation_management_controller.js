import { Controller } from "@hotwired/stimulus"
import { applyTargetSafety } from "../../mixins/target_safety"
import { setVisible } from "../../utils/visibility"

class EvaluationManagementController extends Controller {
  static targets = [
    "statusSelect", 
    "completionFields",
    "rescheduleSection"
  ]

  connect() {
    this.toggleFieldsBasedOnStatus()
  }

  toggleFieldsBasedOnStatus() {
    if (!this.hasRequiredTargets('statusSelect')) {
      return;
    }

    const selectedStatus = this.statusSelectTarget.value

    this.withTarget('completionFields', (target) => {
      const isCompleted = selectedStatus === "completed"
      
      // Use setVisible utility for consistent visibility management
      setVisible(target, isCompleted)
      
      // Set required attributes using the utility
      this.setRequiredAttributes(isCompleted)
    });
  }

  setRequiredAttributes(required) {
    this.withTarget('completionFields', (target) => {
      target.querySelectorAll("[data-completion-required]").forEach(element => {
        // Use setVisible utility's required option for consistency
        setVisible(element, true, { required })
      })
    });
  }
}

// Apply target safety mixin
applyTargetSafety(EvaluationManagementController)

export default EvaluationManagementController
