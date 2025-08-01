import { Controller } from "@hotwired/stimulus"
import { railsRequest } from "../../services/rails_request"
import { applyTargetSafety } from "../../mixins/target_safety"
import Auth, { registerWebAuthn } from "../../auth.js"
import { setVisible } from "../../utils/visibility"

class AddCredentialController extends Controller {
  // Define the expected value for the callback URL
  static values = { callbackUrl: String }
  // Define the target for the nickname input
  static targets = ["nicknameInput", "submitButton"]
  static outlets = ["flash"] // Declare flash outlet

  connect() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("AddCredentialController connected")
    }

    if (!this.hasCallbackUrlValue) {
      console.error("AddCredentialController requires a callback-url value.")
    }

    // Request key for tracking
    this.requestKey = `add-credential-${this.identifier}-${Date.now()}`

    // Get the form element but don't attach a submit handler (using button click)
    this.form = this.element;
  }

  disconnect() {
    // Cancel any pending credential options request
    railsRequest.cancel(this.requestKey)
  }

  // Handle button click  (not form submission)
  async register(event) {
    event.preventDefault(); // Prevent default button click / form submission

    // Show loading state
    this.showFlashMessage("Preparing your security key...", "info");
    this.withTarget('submitButton', (target) => {
      target.disabled = true;
    })

    // Get the nickname
    const nickname = this.safeTarget('nicknameInput')?.value;
    if (!nickname) {
      this.showFlashMessage("Please enter a nickname for your security key.", "error");
      this.withTarget('submitButton', (target) => {
        target.disabled = false;
      })
      return;
    }

    try {
      if (process.env.NODE_ENV !== 'production') {
        console.log("Form action:", this.form.action)
      }

      // Step 1: Use centralized rails request service to get credential options
      const result = await railsRequest.perform({
        method: 'post',
        url: this.form.action,
        body: {}, // Empty JSON body (server gets type from URL)
        key: this.requestKey
      })

      if (result.success) {
        // Parse the credential options
        const credentialOptions = result.data;
        if (process.env.NODE_ENV !== 'production') {
          console.log("Received credential options:", credentialOptions)
        }
        this.showFlashMessage("Please follow your browser's prompts to register your security key...", "info");

        // Check if we have the callback URL value
        if (!this.hasCallbackUrlValue) {
          console.error("Missing callback URL value. Check the data attribute in the view.");
          this.showFlashMessage("Configuration error. Please try again or contact support.", "error");
          this.withTarget('submitButton', (target) => {
            target.disabled = false;
          })
          return;
        }

        // Step 2: Construct the callback URL with nickname
        const callbackUrl = `${this.callbackUrlValue}?credential_nickname=${encodeURIComponent(nickname)}`;
        if (process.env.NODE_ENV !== 'production') {
          console.log("Using callback URL:", callbackUrl)
        }

        // Step 3: Call the WebAuthn API using the Auth module, passing nickname explicitly
        // Pass null for the feedback element as we're using the flash outlet now
        const webauthnResult = await registerWebAuthn(callbackUrl, credentialOptions, nickname, null);

        // Step 4: Handle non-redirect result (errors)
        if (!webauthnResult.success) {
          this.showFlashMessage(webauthnResult.message || "Security key registration failed", "error");
          console.error("Error details:", webauthnResult.details);

          this.withTarget('submitButton', (target) => {
            target.disabled = false;
          })
        }
        // Successful registrations will redirect automatically from auth.js
      }

    } catch (error) {
      console.error("Error in WebAuthn flow:", error);
      this.showFlashMessage(`Error: ${error.message || "Something went wrong. Please try again."}`, "error");

      this.withTarget('submitButton', (target) => {
        target.disabled = false;
      })
    }
  }

  // Use flash outlet for consistent notifications
  showFlashMessage(message, type) {
    if (this.hasFlashOutlet) {
      if (type === 'success') {
        this.flashOutlet.showSuccess(message)
      } else if (type === 'error') {
        this.flashOutlet.showError(message)
      } else {
        this.flashOutlet.showInfo(message)
      }
    } else {
      // Fallback to console if flash outlet is not connected
      if (process.env.NODE_ENV !== 'production') {
        console.warn(`Flash outlet not connected. Message (${type}): ${message}`)
      }
    }
  }
}

// Apply target safety mixin
applyTargetSafety(AddCredentialController)

export default AddCredentialController
