import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open(event) {
    event.preventDefault();
    const modalId = event.currentTarget.getAttribute("data-modal-target");
    const modal = document.getElementById(modalId);
    if (modal) {
      modal.classList.remove("hidden");
    }
  }

  // The close() method adds the "hidden" class to the element where it's defined.
  close(event) {
    event.preventDefault();
    this.element.classList.add("hidden");
  }
}
