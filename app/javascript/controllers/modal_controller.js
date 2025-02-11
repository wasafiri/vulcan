import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Attach listeners for predefined reason buttons within this modal
    this.element.querySelectorAll('.predefined-reason-btn').forEach((btn) => {
      btn.addEventListener('click', (event) => {
        event.preventDefault();
        console.log("Predefined reason button clicked");
        // Read the current proof type from the hidden field inside this modal
        const proofType = this.element.querySelector("#rejection-proof-type").value;
        let reasonText = '';
        if (btn.getAttribute('data-reason-type') === 'address') {
          reasonText = proofType === 'residency'
            ? this.element.dataset.modalAddressMismatchResidencyValue
            : this.element.dataset.modalAddressMismatchIncomeValue;
        } else if (btn.getAttribute('data-reason-type') === 'expired') {
          reasonText = proofType === 'residency'
            ? this.element.dataset.modalExpiredResidencyValue
            : this.element.dataset.modalExpiredIncomeValue;
        }
        // Populate the text area with the predefined reason using the explicit ID
        const textarea = this.element.querySelector('#rejection_reason_field');
        if (textarea) {
          textarea.value = reasonText;
          console.log("Text area populated with:", reasonText);
        } else {
          console.log("Textarea not found");
        }
      });
    });
  }

  open(event) {
    event.preventDefault();
    const modalId = event.currentTarget.getAttribute("data-modal-target");
    const modal = document.getElementById(modalId);
    if (modal) {
      // Check if the triggering element has a data-proof-type attribute
      const proofType = event.currentTarget.getAttribute("data-proof-type");
      if (proofType) {
        // Set the hidden field's value inside the modal
        const hiddenField = modal.querySelector("#rejection-proof-type");
        if (hiddenField) {
          hiddenField.value = proofType;
        }
      }
      modal.classList.remove("hidden");
    }
  }

  close(event) {
    event.preventDefault();
    this.element.classList.add("hidden");
  }
}
