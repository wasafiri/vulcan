import { Controller } from "@hotwired/stimulus"
import { applyTargetSafety } from "../../mixins/target_safety"
import { setVisible } from "../../utils/visibility"

// This controller handles the W9 review form submission logic
class W9ReviewController extends Controller {
  static targets = ["form", "status", "rejectionReason", "approveButton", "rejectButton"]
  static outlets = ["flash"] // Declare flash outlet

  connect() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("W9 Review controller connected")
    }
  }

  approve() {
    if (!this.hasRequiredTargets('status', 'form')) {
      return;
    }

    this.statusTarget.value = 'approved'
    this.formTarget.submit()
  }

  reject() {
    if (!this.hasRequiredTargets('rejectionReason', 'rejectButton', 'status', 'form')) {
      return;
    }

    // If rejection fields are not visible, show them and change button text
    const isHidden = this.rejectionReasonTarget.classList.contains('hidden')
    
    if (isHidden) {
      setVisible(this.rejectionReasonTarget, true)
      this.rejectButtonTarget.textContent = 'Confirm Reject'
      
      // Optionally, focus the first radio button
      const firstRadio = this.rejectionReasonTarget.querySelector('input[type="radio"]')
      if (firstRadio) { firstRadio.focus() }
    } else {
      // Validate rejection fields
      const reasonCodeSelected = Array.from(
        this.rejectionReasonTarget.querySelectorAll('input[name="w9_review[rejection_reason_code]"]')
      ).some(radio => radio.checked)
      
      const reasonText = this.rejectionReasonTarget.querySelector('#w9_review_rejection_reason')?.value.trim() || ''
      
      if (!reasonCodeSelected || reasonText === '') {
        const errorMessage = 'Please select a rejection reason and provide a detailed explanation.'
        if (this.hasFlashOutlet) {
          this.flashOutlet.showError(errorMessage)
        } else {
          alert(errorMessage) // Fallback to alert if flash outlet not connected
        }
      } else {
        this.statusTarget.value = 'rejected'
        this.formTarget.submit()
      }
    }
  }
}

// Apply target safety mixin
applyTargetSafety(W9ReviewController)

export default W9ReviewController
