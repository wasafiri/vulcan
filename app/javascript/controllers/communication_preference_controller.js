import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["infoBox", "emailField", "addressFields", "addressInput"];

  connect() {
    // Set initial state based on selected radio button
    this.toggle();
  }

  toggle(event) {
    const letterSelected = this.element.querySelector('input[value="letter"]').checked;
    const emailField = this.hasEmailFieldTarget ? this.emailFieldTarget : document.querySelector('input[name="constituent[email]"]');
    
    // Handle info box display
    if (letterSelected) {
      this.infoBoxTarget.classList.remove('hidden');
      
      // Make email optional when letter is selected
      if (emailField) {
        emailField.required = false;
      }
      
      // Show address fields and make them required
      if (this.hasAddressFieldsTarget) {
        this.addressFieldsTarget.classList.remove('hidden');
        
        // Make address fields required
        if (this.hasAddressInputTarget) {
          this.addressInputTargets.forEach(input => {
            // Skip optional fields like address line 2
            if (input.dataset.optional !== 'true') {
              input.required = true;
              input.setAttribute('aria-required', 'true');
            }
          });
        }
      }
    } else {
      this.infoBoxTarget.classList.add('hidden');
      
      // Make email required when email is selected
      if (emailField) {
        emailField.required = true;
      }
      
      // Hide address fields and make them not required
      if (this.hasAddressFieldsTarget) {
        this.addressFieldsTarget.classList.add('hidden');
        
        // Make address fields not required
        if (this.hasAddressInputTarget) {
          this.addressInputTargets.forEach(input => {
            input.required = false;
            input.setAttribute('aria-required', 'false');
          });
        }
      }
    }
  }
}
