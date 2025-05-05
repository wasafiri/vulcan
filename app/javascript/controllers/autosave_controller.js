import { Controller } from "@hotwired/stimulus"

// Debounce function to prevent excessive API calls
function debounce(func, wait) {
  let timeout
  return function(...args) {
    clearTimeout(timeout)
    timeout = setTimeout(() => func.apply(this, args), wait)
  }
}

export default class extends Controller {
  static targets = ["form", "autosaveStatus", "fieldError"]
  static values = { 
    url: String,
    debounceWait: { type: Number, default: 1000 }
  }

  connect() {
    this.setupFieldListeners()
    this.debouncedSave = debounce(this.saveField.bind(this), this.debounceWaitValue)
  }

  disconnect() {
    // Clean up any resources or event listeners if needed
  }

  setupFieldListeners() {
    // Get all form inputs except file inputs, buttons, and submit inputs
    const formInputs = this.formTarget.querySelectorAll(
      'input:not([type="file"]):not([type="button"]):not([type="submit"]), select, textarea'
    )
    
    formInputs.forEach(input => {
      // Add blur event listener to trigger autosave
      input.addEventListener('blur', (event) => this.debouncedSave(event.target))
    })
  }

  async saveField(element) {
    // Skip if no element or it's a file input
    if (!element || element.type === 'file') return

    // Get field name and value
    const fieldName = element.name
    let fieldValue = element.value

    // Special handling for checkboxes
    if (element.type === 'checkbox') {
      fieldValue = element.checked
    }

    // Do not save if the field name is empty
    if (!fieldName) return

    // Show saving status
    this.updateStatus("Saving...", "text-indigo-600")

    try {
      // Clear any existing errors for this field
      this.clearFieldErrorNear(element)

      // Get CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]').content

      // Prepare the request
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          field_name: fieldName,
          field_value: fieldValue
        })
      })

      const data = await response.json()

      if (data.success) {
        this.updateStatus("Saved", "text-green-600")
        
        // If this is a new application, update the form action URL 
        // to include the new application ID
        if (data.applicationId && !this.formTarget.action.includes(`/${data.applicationId}`)) {
          const newFormAction = this.formTarget.action.replace(
            '/constituent_portal/applications',
            `/constituent_portal/applications/${data.applicationId}`
          )
          this.formTarget.action = newFormAction
          
          // Update the autosave URL as well
          this.urlValue = this.urlValue.replace(
            '/autosave_field',
            `/${data.applicationId}/autosave_field`
          )
        }
      } else {
        this.updateStatus("Error saving", "text-red-600")
        
        // Display field-specific errors
        if (data.errors) {
          Object.entries(data.errors).forEach(([field, messages]) => {
            if (field === fieldName) {
              this.displayFieldError(element, messages.join(', '))
            }
          })
        }
      }
    } catch (error) {
      console.error('Autosave error:', error)
      this.updateStatus("Failed to save", "text-red-600")
    }

    // Clear status message after a delay
    setTimeout(() => {
      this.updateStatus("", "")
    }, 3000)
  }

  updateStatus(message, cssClass) {
    if (this.hasAutosaveStatusTarget) {
      this.autosaveStatusTarget.textContent = message
      
      // Reset classes
      this.autosaveStatusTarget.className = "text-sm mt-2"
      
      // Add new class if provided
      if (cssClass) {
        this.autosaveStatusTarget.classList.add(cssClass)
      }
    }
  }

  displayFieldError(element, message) {
    // Find or create error element near the field
    const errorContainer = this.findOrCreateFieldErrorElement(element)
    
    if (errorContainer) {
      errorContainer.textContent = message
      errorContainer.classList.remove('hidden')
      errorContainer.classList.add('text-red-600', 'text-sm', 'mt-1')
    }
  }

  clearFieldError(event) {
    this.clearFieldErrorNear(event.target)
  }

  clearFieldErrorNear(element) {
    const errorContainer = this.findFieldErrorElement(element)
    if (errorContainer) {
      errorContainer.textContent = ''
      errorContainer.classList.add('hidden')
    }
  }

  findFieldErrorElement(element) {
    // First look for an existing field error element with a data-field attribute
    const fieldName = element.name
    
    // Look for error elements that are siblings of the input
    const parent = element.parentElement
    if (parent) {
      const errorElem = parent.querySelector(`.field-error-message[data-field="${fieldName}"]`)
      if (errorElem) return errorElem
      
      // Also look for any field error elements without a specific data field that are siblings
      const genericErrorElem = parent.querySelector('.field-error-message:not([data-field])')
      if (genericErrorElem) return genericErrorElem
    }
    
    // Look more broadly for any target
    return this.fieldErrorTargets.find(target => 
      target.dataset.field === fieldName || !target.dataset.field
    )
  }

  findOrCreateFieldErrorElement(element) {
    // First try to find an existing error element
    const existing = this.findFieldErrorElement(element)
    if (existing) return existing
    
    // If not found, create a new one
    const errorElem = document.createElement('p')
    errorElem.className = 'field-error-message text-red-600 text-sm mt-1'
    errorElem.dataset.field = element.name
    
    // Insert after the input element
    const parent = element.parentElement
    if (parent) {
      parent.insertBefore(errorElem, element.nextSibling)
      return errorElem
    }
    
    return null
  }
}
