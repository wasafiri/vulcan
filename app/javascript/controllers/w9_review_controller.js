import { Controller } from "@hotwired/stimulus"

// This controller handles the W9 review form submission logic
export default class extends Controller {
  static targets = ["form", "status", "rejectionReason", "approveButton", "rejectButton"]

  connect() {
    console.log("W9 Review controller connected")
  }

  approve() {
    this.statusTarget.value = 'approved'
    this.formTarget.submit()
  }

  reject() {
    // If rejection fields are not visible, show them and change button text
    if (this.rejectionReasonTarget.classList.contains('hidden')) {
      this.rejectionReasonTarget.classList.remove('hidden')
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
        alert('Please select a rejection reason and provide a detailed explanation.')
      } else {
        this.statusTarget.value = 'rejected'
        this.formTarget.submit()
      }
    }
  }
}
