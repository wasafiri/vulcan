import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["infoBox", "emailField"];

  connect() {
    // Set initial state based on selected radio button
    this.toggle();
  }

  toggle(event) {
    const letterSelected = this.element.querySelector('input[value="letter"]').checked;
    const emailField = this.hasEmailFieldTarget ? this.emailFieldTarget : document.querySelector('input[name="constituent[email]"]');

    if (letterSelected) {
      this.infoBoxTarget.classList.remove('hidden');
      // Make email optional when letter is selected
      if (emailField) {
        emailField.required = false;
      }
    } else {
      this.infoBoxTarget.classList.add('hidden');
      // Make email required when email is selected
      if (emailField) {
        emailField.required = true;
      }
    }
  }
}
