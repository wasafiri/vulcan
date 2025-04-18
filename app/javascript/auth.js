import * as WebAuthnJSON from "@github/webauthn-json"

const Auth = {
  // Core fetch utilities
  getCSRFToken() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]');
    return csrfToken ? csrfToken.getAttribute("content") : null;
  },
  
  // Helper method to generate endpoint URLs for our unified routes
  getEndpointUrl(operation, type, id = null) {
    const basePath = '/two_factor_authentication';
    
    switch(operation) {
      case 'verify':
        return `${basePath}/verify/${type}`;
      case 'options':
        return `${basePath}/verification_options/${type}`;
      case 'create':
        return `${basePath}/credentials/${type}`;
      case 'success':
        return `${basePath}/credentials/${type}/success`;
      case 'destroy':
        return `${basePath}/credentials/${type}/${id}`;
      case 'smsVerify':
        return `${basePath}/credentials/sms/${id}/verify`;
      case 'smsConfirm':
        return `${basePath}/credentials/sms/${id}/confirm`;
      case 'smsResend':
        return `${basePath}/credentials/sms/${id}/resend`;
      default:
        return basePath;
    }
  },

  async sendRequest(url, method, body = null) {
    try {
      const options = {
        method: method,
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": this.getCSRFToken()
        },
        credentials: 'same-origin'
      };

      if (body) {
        options.headers["Content-Type"] = "application/json";
        options.body = JSON.stringify(body);
      }

      const response = await fetch(url, options);
      return this.handleResponse(response);
    } catch (error) {
      console.error(`Network error during ${method} to ${url}:`, error);
      return this.formatError("Network error. Please check your connection and try again.");
    }
  },

  async handleResponse(response) {
    if (response.ok) {
      const data = await response.json();
      console.log("Operation successful:", data);
      
      // Handle redirect if provided, otherwise return success
      if (data.redirect_url) {
        window.location.replace(data.redirect_url);
      }
      return { success: true, data };
    } else {
      try {
        const errorData = await response.json();
        console.error(`Operation failed with status ${response.status}:`, errorData);
        return {
          success: false,
          message: errorData.error || 'Operation failed',
          details: errorData.details || ''
        };
      } catch (e) {
        const errorText = await response.text();
        console.error(`Operation failed with status ${response.status}:`, errorText);
        return {
          success: false,
          message: `Operation failed: ${errorText || 'Unknown error'}`,
          details: ''
        };
      }
    }
  },

  formatError(message, details = "") {
    return {
      success: false,
      message: message,
      details: details
    };
  },

  // UI feedback handling
  updateFeedback(element, message, isError = true) {
    if (!element) return;
    
    element.textContent = message;
    element.classList.remove('hidden');
    
    if (isError) {
      element.classList.add('error');
    } else {
      element.classList.remove('error');
    }
  },

  // Common error message mapper
  getErrorMessage(error) {
    const errorMessages = {
      'NotAllowedError': "The operation was cancelled or timed out.",
      'NotSupportedError': "Your browser doesn't support this feature or device.",
      'SecurityError': "The operation was blocked for security reasons.",
      'AbortError': "The operation was aborted.",
      'InvalidStateError': "The device is not in a valid state for this operation."
    };

    return errorMessages[error.name] || "Failed to complete operation.";
  },

  // WebAuthn operations
  async registerWebAuthnCredential(callbackUrl, credentialOptions, nickname, feedbackElement) { // Added nickname parameter
    if (feedbackElement) {
      this.updateFeedback(feedbackElement, "Preparing to register security key...", false);
    }

    try {
      // Create credential with browser API
      console.log("Requesting credential creation with options:", credentialOptions);
      const credential = await WebAuthnJSON.create({ 
        publicKey: credentialOptions 
      });
      console.log("Browser WebAuthn credential creation successful:", credential);

      // Nickname should be passed explicitly or already be part of the credential object
      // before calling sendRequest. We remove the problematic URL parsing here.

      // The callbackUrl might contain query params (like nickname), but the controller
      // expects the nickname in the POST body. We should POST to the base path.
      const postUrl = callbackUrl.split('?')[0]; 

      console.log(`Sending credential to server at: ${postUrl} with data:`, credential);
      // Add the nickname to the credential object before sending
      if (nickname) {
        credential.credential_nickname = nickname;
        console.log(`Added nickname to credential object: ${nickname}`);
      } else {
        console.warn("Nickname was not provided to registerWebAuthnCredential");
      }
      
      // Structure the data as expected by the controller:
      // Separate nickname from the main credential data.
      const postData = {
        ...credential, // Spread the credential data from WebAuthnJSON.create()
        credential_nickname: nickname // Add nickname as a separate top-level key
      };

      const result = await this.sendRequest(postUrl, 'POST', postData); 
      
      if (!result.success && feedbackElement) {
        this.updateFeedback(feedbackElement, result.message);
      }
      
      return result;
    } catch (error) {
      console.error("WebAuthn credential creation failed:", error);
      const message = this.getErrorMessage(error);
      this.updateFeedback(feedbackElement, message);
      return this.formatError(message, error.message);
    }
  },

  async verifyWebAuthnCredential(credentialOptions, callbackUrl, feedbackElement) {
    if (feedbackElement) {
      this.updateFeedback(feedbackElement, "Preparing to verify security key...", false);
    }

    try {
      // Get assertion with browser API
      console.log("Requesting credential assertion with options:", credentialOptions);
      const credential = await WebAuthnJSON.get({ 
        publicKey: credentialOptions 
      });
      console.log("Credential assertion successful, sending to server:", credential);

      // Wrap the credential in two_factor_authentication as expected by the controller
      const wrappedCredential = { two_factor_authentication: credential };
      console.log("Sending wrapped credential to server:", wrappedCredential);
      
      // Send to server and handle result
      const result = await this.sendRequest(callbackUrl || this.getEndpointUrl('verify', 'webauthn'), 'POST', wrappedCredential);
      
      if (!result.success && feedbackElement) {
        this.updateFeedback(feedbackElement, result.message);
      }
      
      return result;
    } catch (error) {
      console.error("Credential assertion failed:", error);
      const message = this.getErrorMessage(error);
      this.updateFeedback(feedbackElement, message);
      return this.formatError(message, error.message);
    }
  },

  // TOTP operations
  async verifyTotpCode(code, callbackUrl, feedbackElement) {
    if (feedbackElement) {
      this.updateFeedback(feedbackElement, "Verifying code...", false);
    }

    console.log("Verifying TOTP code");
    const result = await this.sendRequest(callbackUrl, 'POST', { 
      code: code, 
      method: 'totp' 
    });

    if (!result.success && feedbackElement) {
      this.updateFeedback(feedbackElement, result.message);
    }

    return result;
  },

  // SMS operations
  async verifySmsCode(code, callbackUrl, feedbackElement) {
    if (feedbackElement) {
      this.updateFeedback(feedbackElement, "Verifying code...", false);
    }

    console.log("Verifying SMS code");
    const result = await this.sendRequest(callbackUrl, 'POST', { 
      code: code, 
      method: 'sms' 
    });

    if (!result.success && feedbackElement) {
      this.updateFeedback(feedbackElement, result.message);
    }

    return result;
  },

  async requestSmsCode(url, feedbackElement) {
    if (feedbackElement) {
      this.updateFeedback(feedbackElement, "Sending verification code...", false);
    }

    console.log("Requesting SMS verification code");
    const result = await this.sendRequest(url, 'POST');

    if (result.success && feedbackElement) {
      this.updateFeedback(feedbackElement, "Verification code sent. Please check your phone.", false);
    } else if (!result.success && feedbackElement) {
      this.updateFeedback(feedbackElement, result.message);
    }

    return result;
  }
};

// Export both the Auth object and individual functions for backward compatibility
// Updated 'create' signature to include nickname
const create = (callbackUrl, credentialOptions, nickname, feedbackElement) => 
  Auth.registerWebAuthnCredential(callbackUrl, credentialOptions, nickname, feedbackElement);

const get = (credentialOptions, callbackUrl, feedbackElement) => 
  Auth.verifyWebAuthnCredential(credentialOptions, callbackUrl, feedbackElement);

const verifyTotpCode = (code, callbackUrl, feedbackElement) => 
  Auth.verifyTotpCode(code, callbackUrl, feedbackElement);

const verifySmsCode = (code, callbackUrl, feedbackElement) => 
  Auth.verifySmsCode(code, callbackUrl, feedbackElement);

const requestSmsCode = (url, feedbackElement) => 
  Auth.requestSmsCode(url, feedbackElement);

export { Auth as default, create, get, verifyTotpCode, verifySmsCode, requestSmsCode };
