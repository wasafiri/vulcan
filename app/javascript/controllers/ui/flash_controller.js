import { Controller } from "@hotwired/stimulus"

/**
 * Flash Controller
 * 
 * Provides centralized toast notification functionality.
 * Replaces ad-hoc document.body.appendChild patterns with standardized styling.
 */
export default class extends Controller {
  static values = {
    autoHide: { type: Boolean, default: true },
    hideDelay: { type: Number, default: 3000 },
    errorHideDelay: { type: Number, default: 5000 }
  }

  connect() {
    // Listen for global flash events from RailsRequestService
    this._boundHandleFlashEvent = this.handleFlashEvent.bind(this)
    document.addEventListener('rails-request:flash', this._boundHandleFlashEvent)
    
    // Process any queued flash messages from server-rendered partials
    this.processQueuedMessages()
  }

  disconnect() {
    // Clean up global event listener
    if (this._boundHandleFlashEvent) {
      document.removeEventListener('rails-request:flash', this._boundHandleFlashEvent)
    }
  }

  /**
   * Handle flash events from RailsRequestService
   * @param {CustomEvent} event - The flash event
   */
  handleFlashEvent(event) {
    const { message, type } = event.detail
    this.show(message, type)
  }

  /**
   * Show a success message
   * @param {string} message The message to display
   */
  showSuccess(message) {
    this.show(message, 'success');
  }

  /**
   * Show an error message
   * @param {string} message The message to display
   */
  showError(message) {
    this.show(message, 'error');
  }

  /**
   * Show a general info message
   * @param {string} message The message to display
   */
  showInfo(message) {
    this.show(message, 'info');
  }

  /**
   * Show a flash message
   * @param {string} message The message to display
   * @param {string} type The type of message (success, error, info)
   */
  show(message, type = 'info') {
    // Prevent notification spam
    this.cleanupOldNotifications();
    
    const notification = this.createNotification(message, type);
    document.body.appendChild(notification);
    
    if (this.autoHideValue) {
      const delay = type === 'error' ? this.errorHideDelayValue : this.hideDelayValue;
      setTimeout(() => {
        if (notification.parentNode) {
          notification.remove();
        }
      }, delay);
    }
  }

  /**
   * Create a notification element
   * @param {string} message The message to display
   * @param {string} type The type of message
   * @returns {HTMLElement} The notification element
   */
  createNotification(message, type) {
    const notification = document.createElement('div');
    notification.className = this.getNotificationClasses(type);
    notification.setAttribute('role', 'alert');
    notification.setAttribute('aria-live', 'polite');
    notification.setAttribute('data-flash-notification', 'true');
    
    // Create icon container (safe HTML - controlled by us)
    const iconContainer = document.createElement('div');
    iconContainer.innerHTML = this.getIcon(type);
    
    // Create content container with safe text handling
    const contentDiv = document.createElement('div');
    const labelSpan = document.createElement('span');
    labelSpan.className = 'font-bold';
    labelSpan.textContent = this.getLabel(type); // Safe text content
    
    const messageText = document.createTextNode(` ${message}`); // Safe text node
    
    contentDiv.appendChild(labelSpan);
    contentDiv.appendChild(messageText);
    
    // Create close button
    const closeButton = this.createCloseButton();
    
    notification.appendChild(iconContainer);
    notification.appendChild(contentDiv);
    notification.appendChild(closeButton);
    
    return notification;
  }

  /**
   * Get CSS classes for notification type
   * @param {string} type The notification type
   * @returns {string} CSS classes
   */
  getNotificationClasses(type) {
    const baseClasses = 'fixed top-4 right-4 px-4 py-3 rounded border z-50 flex items-center space-x-3 shadow-lg';
    
    switch (type) {
      case 'success':
        return `${baseClasses} bg-green-100 border-green-400 text-green-700`;
      case 'error':
        return `${baseClasses} bg-red-100 border-red-400 text-red-700`;
      case 'warning':
        return `${baseClasses} bg-yellow-100 border-yellow-400 text-yellow-700`;
      case 'info':
      default:
        return `${baseClasses} bg-blue-100 border-blue-400 text-blue-700`;
    }
  }

  /**
   * Get icon SVG for notification type
   * @param {string} type The notification type
   * @returns {string} SVG icon HTML
   */
  getIcon(type) {
    switch (type) {
      case 'success':
        return `<svg class="w-5 h-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
        </svg>`;
      case 'error':
        return `<svg class="w-5 h-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
        </svg>`;
      case 'warning':
        return `<svg class="w-5 h-5 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"></path>
        </svg>`;
      case 'info':
      default:
        return `<svg class="w-5 h-5 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"></path>
        </svg>`;
    }
  }

  /**
   * Get label for notification type
   * @param {string} type The notification type
   * @returns {string} Label text
   */
  getLabel(type) {
    switch (type) {
      case 'success':
        return 'Success!';
      case 'error':
        return 'Error!';
      case 'warning':
        return 'Warning:';
      case 'info':
      default:
        return 'Info:';
    }
  }

  /**
   * Process queued flash messages from server-rendered partials
   */
  processQueuedMessages() {
    const queuedMessages = window._queuedFlashMessages || [];
    queuedMessages.forEach(eventData => {
      this.show(eventData.message, eventData.type);
    });
    window._queuedFlashMessages = [];
  }

  /**
   * Clean up old notifications to prevent memory leaks
   */
  cleanupOldNotifications() {
    const existing = document.querySelectorAll('[data-flash-notification]');
    const maxNotifications = 5;
    
    if (existing.length >= maxNotifications) {
      // Remove oldest notifications
      const toRemove = Array.from(existing).slice(0, existing.length - maxNotifications + 1);
      toRemove.forEach(el => el.remove());
    }
  }

  /**
   * Create close button for notifications
   * @returns {HTMLElement} Close button element
   */
  createCloseButton() {
    const closeButton = document.createElement('button');
    closeButton.className = 'ml-auto text-current opacity-70 hover:opacity-100';
    closeButton.setAttribute('aria-label', 'Close notification');
    closeButton.addEventListener('click', (e) => {
      e.currentTarget.parentElement.remove();
    });
    
    closeButton.innerHTML = `
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
      </svg>
    `;
    
    return closeButton;
  }
}
