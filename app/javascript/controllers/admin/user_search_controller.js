import BaseFormController from "../base/form_controller"
import { railsRequest } from "../../services/rails_request"
import { applyTargetSafety } from "../../mixins/target_safety"
import { setVisible } from "../../utils/visibility"

class UserSearchController extends BaseFormController {
  static targets = [
    "searchInput",
    "searchResults", 
    "guardianForm",
    "createButton",
    "guardianFormField",
    "clearSearchButton"
  ]
  
  static outlets = ["guardian-picker", "flash"]
  
  static values = {
    searchUrl: String,
    createUserUrl: String, 
    defaultRole: { type: String, default: "guardian" }
  }

  connect() {
    super.connect()
    
    // Add debounced search listener using our new pattern
    if (this.safeTarget('searchInput')) {
      this.addDebouncedListener(
        this.searchInputTarget,
        'input',
        this.performSearch,
        300
      )
    }
  }

  async performSearch(event) {
    const q = event.target.value.trim()
    
    if (q.length === 0) {
      this.clearResults()
      return
    }

    await this.executeSearch(q)
  }

  async executeSearch(q) {
    if (!q) return

    try {
      const result = await railsRequest.perform({
        method: 'get',
        url: `${this.searchUrlValue}?q=${encodeURIComponent(q)}&role=${this.defaultRoleValue}`,
        key: 'user-search',
        headers: { Accept: 'text/vnd.turbo-stream.html, text/html' }
      })

      if (result.success) {
        this.displaySearchResults(result.data)
      }

    } catch (error) {
      if (error.name !== 'RequestError') {
        console.error('Search error:', error)
      }
      // Use flash outlet for consistent error notifications
      this.showErrorNotification(error.message || 'Search failed')
    }
  }

  displaySearchResults(html) {
    this.withTarget('searchResults', (target) => {
      target.innerHTML = html
      setVisible(target, true)
    })
  }

  clearResults() {
    this.withTarget('searchResults', (target) => {
      target.innerHTML = ""
      setVisible(target, false)
    })
  }

  clearSearchAndShowForm() {
    this.withTarget('searchInput', (input) => {
      input.value = ""
      input.focus()
    })
    
    this.clearResults()
    
    if (this.hasGuardianPickerOutlet) {
      this.guardianPickerOutlet.clearSelection()
    }
  }

  selectUser(event) {
    event.preventDefault()
    const { userId, userName, ...userData } = event.currentTarget.dataset

    if (!userId || !userName) {
      console.error("User data missing from selection")
      return
    }

    // Use safe HTML escaping for security
    const displayHTML = this.buildUserDisplayHTML(this.escapeHtml(userName), userData)
    
    if (this.hasGuardianPickerOutlet) {
      this.guardianPickerOutlet.selectGuardian(userId, displayHTML)
    }
    
    this.clearResults()
  }

  buildUserDisplayHTML(userName, userData) {
    const { userEmail, userPhone, userAddress1, userAddress2, userCity, userState, userZip, userDependentsCount = '0' } = userData
    
    // Escape all user data for XSS prevention
    const safeEmail = userEmail ? this.escapeHtml(userEmail) : ''
    const safePhone = userPhone ? this.escapeHtml(userPhone) : ''
    const safeAddress1 = userAddress1 ? this.escapeHtml(userAddress1) : ''
    const safeAddress2 = userAddress2 ? this.escapeHtml(userAddress2) : ''
    const safeCity = userCity ? this.escapeHtml(userCity) : ''
    const safeState = userState ? this.escapeHtml(userState) : ''
    const safeZip = userZip ? this.escapeHtml(userZip) : ''
    
    let html = `<span class="font-medium">${userName}</span>`
    
    // Contact info
    const contactInfo = []
    if (safeEmail) contactInfo.push(`<span class="text-indigo-700">${safeEmail}</span>`)
    if (safePhone) contactInfo.push(`<span class="text-gray-600">Phone: ${safePhone}</span>`)
    
    if (contactInfo.length > 0) {
      html += `<div class="text-sm text-gray-600 mt-1">${contactInfo.join(' • ')}</div>`
    }
    
    // Address
    const addressParts = [safeAddress1, safeAddress2, safeCity, safeState, safeZip].filter(Boolean)
    if (addressParts.length > 0) {
      html += `<div class="text-sm text-gray-600 mt-1">${addressParts.join(', ')}</div>`
    } else {
      html += `<div class="text-sm text-gray-600 mt-1 italic">No address information available</div>`
    }
    
    // Dependents
    const dependentsCount = parseInt(userDependentsCount) || 0
    const dependentsText = dependentsCount === 1 ? "1 dependent" : `${dependentsCount} dependents`
    html += `<div class="text-sm text-gray-600 mt-1">Currently has ${dependentsText}</div>`
    
    return html
  }

  // XSS prevention helper
  escapeHtml(unsafe) {
    return unsafe
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }

  // Override from BaseFormController for custom validation
  async validateBeforeSubmit(data) {
    if (!data.first_name || !data.last_name || !data.email) {
      return { 
        valid: false,
        errors: {
          first_name: !data.first_name ? 'First name is required' : null,
          last_name: !data.last_name ? 'Last name is required' : null,
          email: !data.email ? 'Email is required' : null
        }
      }
    }
    return { valid: true }
  }

  // Override from BaseFormController for success handling
  async handleSuccess(data) {
    if (data.user) {
      this.handleGuardianCreationSuccess(data)
      this.showSuccessNotification("Guardian created successfully")
    } else {
      super.handleSuccess(data)
    }
  }

  handleGuardianCreationSuccess(data) {
    const { user } = data
    const displayHTML = this.buildUserDisplayHTML(
      this.escapeHtml(`${user.first_name} ${user.last_name}`),
      {
        userEmail: user.email,
        userPhone: user.phone,
        userAddress1: user.physical_address_1,
        userAddress2: user.physical_address_2,
        userCity: user.city,
        userState: user.state,
        userZip: user.zip_code,
        userDependentsCount: '0'
      }
    )
    
    if (this.hasGuardianPickerOutlet) {
      this.guardianPickerOutlet.selectGuardian(user.id.toString(), displayHTML)
    }
    
    this.clearSearchAndShowForm()
  }

  showSuccessNotification(message) {
    if (this.hasFlashOutlet) {
      this.flashOutlet.showSuccess(message)
    } else {
      super.showStatus(message, 'success')
    }
  }

  showErrorNotification(message) {
    if (this.hasFlashOutlet) {
      this.flashOutlet.showError(message)
    } else {
      super.showStatus(message, 'error')
    }
  }

  // Override disconnect to add event handler cleanup
  disconnect() {
    // Clean up managed event listeners
    this.cleanupAllEventHandlers()
    
    // Call parent disconnect
    super.disconnect()
  }

  // Add event handler management mixin methods
  addDebouncedListener(element, event, handler, wait = 300) {
    if (!element) return
    
    const debounced = this.debounce(handler.bind(this), wait)
    element.addEventListener(event, debounced)
    
    // Store for cleanup
    this._managedListeners = this._managedListeners || []
    this._managedListeners.push({ element, event, handler: debounced })
  }

  cleanupAllEventHandlers() {
    if (this._managedListeners) {
      this._managedListeners.forEach(({ element, event, handler }) => {
        element.removeEventListener(event, handler)
      })
      this._managedListeners = []
    }
  }

  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }
}

// Apply target safety mixin
applyTargetSafety(UserSearchController)

export default UserSearchController
