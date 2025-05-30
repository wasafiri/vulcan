import { Controller } from "@hotwired/stimulus"
import Auth from "../auth";

export default class extends Controller {
  connect() {
    console.debug("[CredentialAuth] connected to", this.element);
  }

  // Fired when "Verify with Security Key" is clicked
  async startVerification(event) {
    event.preventDefault();
    
    // Disable the button to prevent double submissions
    const button = event.currentTarget;
    button.disabled = true;
    
    console.debug("[CredentialAuth] fetching WebAuthn options...");

    const form = document.getElementById("webauthn-form");
    const url = form.action;

    try {
      const response = await fetch(url, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error ${response.status}`);
      }

      const options = await response.json();
      console.debug("[CredentialAuth] options received", options);

      await this.verifyKey(options);
    } catch (err) {
      // Re-enable the button on error
      button.disabled = false;
      console.error("[CredentialAuth] error fetching options:", err);
      this.handleError(err);
    }
  }

  // Process the options and request WebAuthn verification
  async verifyKey(options) {
    console.debug("[CredentialAuth] processing options:", options);

    // The Auth module now handles the browser interaction (WebAuthnJSON.get) internally.
    // We just need to call the verification method with the options.

    try {
      const verifyUrl = Auth.getEndpointUrl('verify', 'webauthn');
      console.debug("[CredentialAuth] initiating verification with server at:", verifyUrl);
      // Pass the options directly; Auth.verifyWebAuthnCredential handles the browser prompt and server call.
      const verification = await Auth.verifyWebAuthnCredential(options, verifyUrl); 
      console.debug("[CredentialAuth] server verification response:", verification);
      
      // Handle success case - redirect if we got a redirect URL
      if (verification.success && verification.data && verification.data.redirect_url) {
        window.location.replace(verification.data.redirect_url);
      } else if (verification.success) {
        // Fallback to root if no redirect URL provided
        window.location.replace('/');
      } else {
        // Re-enable button if verification returned a failure but didn't throw an error
        const button = document.querySelector('[data-action*="credential-authenticator#startVerification"]');
        if (button) button.disabled = false;
      }
    } catch (err) {
      // Re-enable the verify button if it exists
      const button = document.querySelector('[data-action*="credential-authenticator#startVerification"]');
      if (button) button.disabled = false;
      
      console.error("[CredentialAuth] server verification failed:", err);
      return alert("Server verification failed:\n" + err.message);
    }
  }

  // Handle errors during the WebAuthn flow
  handleError(error) {
    console.error("[CredentialAuth] authentication flow error:", error);
    alert("Could not retrieve authentication options. Please try again.");
  }
}
