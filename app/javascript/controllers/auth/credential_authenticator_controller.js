import { Controller } from "@hotwired/stimulus"
import { applyTargetSafety } from "../../mixins/target_safety"
import { verifyWebAuthn } from "../../auth"

class CredentialAuthenticatorController extends Controller {
  static targets = [
    "webauthnForm",
    "verificationButton"
  ]

  // Declare the flash outlet so we can do this.flashOutlet.showXxx(...)
  static outlets = ["flash"]

  connect() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("CredentialAuthenticatorController connected")
    }
  }

  disconnect() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("CredentialAuthenticatorController disconnected")
    }
  }

  // Fired when "Verify with Security Key" is clicked
  async startVerification(event) {
    event.preventDefault()

    if (!this.hasRequiredTargets('webauthnForm')) {
      // If the form target is missing, bail out
      return
    }

    const form = this.webauthnFormTarget
    const formData = new FormData(form)

    const challenge = formData.get('challenge')
    const timeout = parseInt(formData.get('timeout')) || 30000
    const rpId = formData.get('rp_id')
    let allowCredentials

    try {
      allowCredentials = JSON.parse(formData.get('allow_credentials') || '[]')
    } catch {
      allowCredentials = []
    }

    if (!challenge) {
      console.error("No challenge found in form data")
      this.showFlashMessage("Verification failed: No challenge provided.", "error")
      return
    }

    try {
      const credentialOptions = {
        challenge,
        timeout,
        rpId,
        allowCredentials,
        userVerification: "required"
      }

      const callbackUrl = form.action

      // We pass `null` for the feedback element, since we now use the flash outlet
      const result = await verifyWebAuthn(
        credentialOptions,
        callbackUrl,
        null
      )

      if (result.success) {
        if (process.env.NODE_ENV !== 'production') {
          console.log("WebAuthn verification successful")
        }
        this.showFlashMessage("Security key verified successfully!", "success")
      } else {
        this.showFlashMessage(result.message || "Security key verification failed", "error")
        if (process.env.NODE_ENV !== 'production') {
          console.error("WebAuthn verification failed:", result.details)
        }
      }
    } catch (error) {
      console.error("WebAuthn verification error:", error)
      this.showFlashMessage(`Error: ${error.message || "Something went wrong."}`, "error")
    }
  }

  // Alternate entry point if you want to verify a key outside of the form flow
  async verifyKey(options) {
    try {
      const result = await verifyWebAuthn(options, null, null)

      if (result.success) {
        this.withTarget('verificationButton', (button) => {
          button.textContent = "Verified"
          button.disabled = true
        })
        this.showFlashMessage("Security key verified successfully!", "success")
      } else {
        this.showFlashMessage(result.message || "Security key verification failed", "error")
        if (process.env.NODE_ENV !== 'production') {
          console.error("Key verification error:", result.details)
        }
      }

      return result
    } catch (error) {
      console.error("Key verification error:", error)
      this.showFlashMessage(`Error: ${error.message || "Something went wrong."}`, "error")
      return { success: false, message: error.message }
    }
  }

  // Use the flash outlet (if connected) to show messages, otherwise fallback to console
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
      if (process.env.NODE_ENV !== 'production') {
        console.warn(`Flash outlet not connected. Message (${type}): ${message}`)
      }
    }
  }
}

// Apply target safety mixin
applyTargetSafety(CredentialAuthenticatorController)

export default CredentialAuthenticatorController
