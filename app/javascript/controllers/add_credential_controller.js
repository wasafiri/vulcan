import { Controller } from "@hotwired/stimulus"
import Auth, { create } from "../auth.js";

export default class extends Controller {
  // Define the expected value for the callback URL
  static values = { callbackUrl: String }
  // Define the target for the nickname input
  static targets = ["nicknameInput", "statusMessage", "submitButton"]

  connect() {
    console.log("AddCredentialController connected");
    if (!this.hasCallbackUrlValue) {
      console.error("AddCredentialController requires a callback-url value.");
    }
    
    // Get the form element but don't attach a submit handler (using button click instead)
    this.form = this.element;
  }

  // Handle button click instead of form submission
  async register(event) {
    event.preventDefault(); // Prevent default button click / form submission
    // event.stopImmediatePropagation(); // Stop other listeners on this element for this event - Removed as likely redundant

    // Show loading state
    this.updateStatus("Preparing your security key...", "info");
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true;
    }

    // Get the nickname
    const nickname = this.nicknameInputTarget.value;
    if (!nickname) {
      this.updateStatus("Please enter a nickname for your security key.", "error");
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false;
      }
      return;
    }

    try {
      // Create FormData from the form - Removed, we send JSON now
      // const formData = new FormData(this.form);
      console.log("Form action:", this.form.action);

      // Prepare an empty JSON body (server gets type from URL)
      const requestBody = {};

      // Step 1: Submit to get the credential options
      const response = await fetch(this.form.action, {
        method: "POST",
        body: JSON.stringify(requestBody), // Send as JSON string
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json", // Explicitly set Content-Type
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        credentials: "same-origin"
      });

      if (!response.ok) {
        throw new Error(`Server error: ${response.status}`);
      }

      // Parse the credential options
      const credentialOptions = await response.json();
      console.log("Received credential options:", credentialOptions);
      this.updateStatus("Please follow your browser's prompts to register your security key...", "info");

      // Check if we have the callback URL value
      if (!this.hasCallbackUrlValue) {
        console.error("Missing callback URL value. Check the data attribute in the view.");
        this.updateStatus("Configuration error. Please try again or contact support.", "error");
        if (this.hasSubmitButtonTarget) {
          this.submitButtonTarget.disabled = false;
        }
        return;
      }

      // Step 2: Construct the callback URL with nickname
      const callbackUrl = `${this.callbackUrlValue}?credential_nickname=${encodeURIComponent(nickname)}`;
      console.log("Using callback URL:", callbackUrl);
      // Step 3: Call the WebAuthn API using the new Auth module, passing nickname explicitly
      const result = await create(callbackUrl, credentialOptions, nickname, this.statusMessageTarget);
      
      // Step 4: Handle non-redirect result (errors)
      if (!result.success) {
        this.updateStatus(result.message || "Security key registration failed", "error");
        console.error("Error details:", result.details);
        
        if (this.hasSubmitButtonTarget) {
          this.submitButtonTarget.disabled = false;
        }
      }
      // Successful registrations will redirect automatically from auth.js
    } catch (error) {
      console.error("Error in WebAuthn flow:", error);
      this.updateStatus(`Error: ${error.message || "Something went wrong. Please try again."}`, "error");
      
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false;
      }
    }
    // return false; // Forcefully prevent default form submission - Removed as likely redundant
  }

  // Helper to update status messages
  updateStatus(message, type = "info") {
    console.log(`Status update (${type}): ${message}`);
    
    if (this.hasStatusMessageTarget) {
      this.statusMessageTarget.textContent = message;
      
      // Remove previous status classes
      this.statusMessageTarget.classList.remove("text-green-600", "text-red-600", "text-blue-600");
      
      // Add class based on type
      if (type === "error") {
        this.statusMessageTarget.classList.add("text-red-600");
      } else if (type === "success") {
        this.statusMessageTarget.classList.add("text-green-600");
      } else {
        this.statusMessageTarget.classList.add("text-blue-600");
      }
      
      // Show the status message
      this.statusMessageTarget.classList.remove("hidden");
    }
  }
}
