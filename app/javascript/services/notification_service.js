// app/javascript/services/notification_service.js

/**
 * Centralized client-side notification service to display toast notifications, integrating with Turbo
 * and replacing the legacy flash system.
 */
class NotificationService {
  constructor() {
    this.container = null; // Will be lazily created when needed
    this.maxNotifications = 5; // Limit the number of notifications displayed at once
    this.hideDelay = 3000; // Default hide delay for success/info
    this.errorHideDelay = 5000; // Hide delay for errors
    this.setupEventListeners();
  }

  /**
   * Gets or creates the main container for notifications.
   * The container is marked with `data-turbo-permanent` to persist across Turbo navigations.
   * @returns {HTMLElement|null} The notification container element, or null if DOM is not ready.
   */
  getOrCreateContainer() {
    // Return cached container if available
    if (this.container) {
      return this.container;
    }

    // Check if DOM is ready
    if (!document.body) {
      console.warn('[NotificationService] document.body not available yet, deferring container creation');
      return null;
    }

    let container = document.getElementById('notification-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'notification-container';
      container.className = 'fixed top-4 right-4 z-[9999] space-y-2 pointer-events-none';
      container.setAttribute('data-turbo-permanent', ''); // Persist across Turbo navigations
      document.body.appendChild(container);
    }

    // Cache the container
    this.container = container;
    return container;
  }

  /**
   * Sets up event listeners for Turbo and custom events.
   */
  setupEventListeners() {
    // Process server-side flash messages on initial page load and Turbo navigations
    document.addEventListener('turbo:load', this.processQueuedMessages.bind(this));
    // Listen for custom events dispatched by RailsRequestService or other JS
    document.addEventListener('app:notification', this.handleAppNotificationEvent.bind(this));
  }

  /**
   * Handles custom 'app:notification' events.
   * @param {CustomEvent} event - The custom event containing notification details.
   */
  handleAppNotificationEvent(event) {
    const { message, type, options } = event.detail;
    this.show(message, type, options);
  }

  /**
   * Shows a success notification.
   * @param {string} message - The message to display.
   * @param {object} [options={}] - Additional options for the notification.
   */
  showSuccess(message, options = {}) {
    this.show(message, 'success', options);
  }

  /**
   * Shows an error notification.
   * @param {string} message - The message to display.
   * @param {object} [options={}] - Additional options for the notification.
   */
  showError(message, options = {}) {
    this.show(message, 'error', options);
  }

  /**
   * Shows a warning notification.
   * @param {string} message - The message to display.
   * @param {object} [options={}] - Additional options for the notification.
   */
  showWarning(message, options = {}) {
    this.show(message, 'warning', options);
  }

  /**
   * Shows an info notification.
   * @param {string} message - The message to display.
   * @param {object} [options={}] - Additional options for the notification.
   */
  showInfo(message, options = {}) {
    this.show(message, 'info', options);
  }

  /**
   * Displays a notification toast.
   * @param {string} message - The message content.
   * @param {string} type - The type of notification ('success', 'error', 'warning', 'info').
   * @param {object} [options={}] - Additional options:
   *   - autoHide {boolean}: Whether the notification should auto-hide (default: true).
   *   - hideDelay {number}: Custom hide delay in ms.
   *   - permanent {boolean}: If true, notification will not auto-hide and will persist until manually dismissed.
   */
  show(message, type = 'info', options = {}) {
    // Ensure container is available
    const container = this.getOrCreateContainer();
    if (!container) {
      console.warn('[NotificationService] Container not available, cannot show notification:', message);
      return;
    }

    this.cleanupOldNotifications();

    const notificationElement = this.createNotificationElement(message, type);
    container.appendChild(notificationElement);

    const autoHide = options.permanent ? false : (options.autoHide ?? true);
    const delay = options.hideDelay || (type === 'error' ? this.errorHideDelay : this.hideDelay);

    if (autoHide) {
      setTimeout(() => this.dismiss(notificationElement), delay);
    }
  }

  /**
   * Creates the HTML element for a single notification.
   * @param {string} message - The message content.
   * @param {string} type - The type of notification.
   * @returns {HTMLElement} The created notification element.
   */
  createNotificationElement(message, type) {
    const notification = document.createElement('div');
    notification.className = this.getNotificationClasses(type);
    notification.setAttribute('role', 'alert');
    notification.setAttribute('aria-live', 'polite');
    notification.setAttribute('data-notification-type', type); // For styling/testing
    notification.classList.add('pointer-events-auto'); // Make it clickable/hoverable

    // Icon
    const iconContainer = document.createElement('div');
    iconContainer.className = 'flex-shrink-0';
    iconContainer.innerHTML = this.getIconSVG(type);
    notification.appendChild(iconContainer);

    // Content
    const contentDiv = document.createElement('div');
    contentDiv.className = 'ml-3 flex-1 pt-0.5';
    const title = document.createElement('p');
    title.className = `text-sm font-medium ${this.getTextColor(type)}`;
    title.textContent = this.getTitle(type);
    const messageP = document.createElement('p');
    messageP.className = `mt-1 text-sm ${this.getTextColor(type)}`;
    messageP.textContent = message; // Use textContent for safety
    contentDiv.appendChild(title);
    contentDiv.appendChild(messageP);
    notification.appendChild(contentDiv);

    // Close button
    const closeButtonContainer = document.createElement('div');
    closeButtonContainer.className = 'ml-4 flex-shrink-0 flex';
    const closeButton = document.createElement('button');
    closeButton.className = `inline-flex ${this.getTextColor(type)} rounded-md bg-white/50 hover:bg-white/70 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-gray-50 focus:ring-indigo-500`;
    closeButton.innerHTML = `<span class="sr-only">Close</span><svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" /></svg>`;
    closeButton.addEventListener('click', () => this.dismiss(notification));
    closeButtonContainer.appendChild(closeButton);
    notification.appendChild(closeButtonContainer);

    return notification;
  }

  /**
   * Gets the base CSS classes for a notification.
   * @param {string} type - The notification type.
   * @returns {string} CSS classes.
   */
  getNotificationClasses(type) {
    const base = 'max-w-sm w-full bg-white shadow-lg rounded-lg ring-1 ring-black ring-opacity-5 overflow-hidden';
    switch (type) {
      case 'success': return `${base} border-l-4 border-green-400`;
      case 'error': return `${base} border-l-4 border-red-400`;
      case 'warning': return `${base} border-l-4 border-yellow-400`;
      case 'info': return `${base} border-l-4 border-blue-400`;
      default: return base;
    }
  }

  /**
   * Gets the SVG icon for a notification type.
   * @param {string} type - The notification type.
   * @returns {string} SVG HTML.
   */
  getIconSVG(type) {
    switch (type) {
      case 'success': return `<svg class="h-6 w-6 text-green-400" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm13.36-1.814a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z" clip-rule="evenodd" /></svg>`;
      case 'error': return `<svg class="h-6 w-6 text-red-400" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm-1.72 6.97a.75.75 0 10-1.06 1.06L10.94 12l-2.72 2.72a.75.75 0 101.06 1.06L12 13.06l2.72 2.72a.75.75 0 101.06-1.06L13.06 12l2.72-2.72a.75.75 0 00-1.06-1.06L12 10.94l-2.72-2.72z" clip-rule="evenodd" /></svg>`;
      case 'warning': return `<svg class="h-6 w-6 text-yellow-400" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M9.401 3.003c1.155-2.003 4.043-2.003 5.198 0l5.197 9.003c1.155 2.003-.309 4.503-2.599 4.503H6.803c-2.29 0-3.754-2.5-2.599-4.503l5.197-9.003zM12 8.25a.75.75 0 01.75.75v3.75a.75.75 0 01-1.5 0V9a.75.75 0 01.75-.75zm0 8.25a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd" /></svg>`;
      case 'info': return `<svg class="h-6 w-6 text-blue-400" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm8.706-1.455a.75.75 0 00-1.08 1.058l3.75 4.5a.75.75 0 001.154-.104 6.001 6.001 0 00-3.874-5.854zM12 9a.75.75 0 100-1.5.75.75 0 000 1.5z" clip-rule="evenodd" /></svg>`;
      default: return '';
    }
  }

  /**
   * Gets the title text for a notification type.
   * @param {string} type - The notification type.
   * @returns {string} The title text.
   */
  getTitle(type) {
    switch (type) {
      case 'success': return 'Success!';
      case 'error': return 'Error!';
      case 'warning': return 'Warning!';
      case 'info': return 'Info:';
      default: return '';
    }
  }

  /**
   * Gets the text color class for a notification type.
   * @param {string} type - The notification type.
   * @returns {string} Tailwind CSS text color class.
   */
  getTextColor(type) {
    switch (type) {
      case 'success': return 'text-green-800';
      case 'error': return 'text-red-800';
      case 'warning': return 'text-yellow-800';
      case 'info': return 'text-blue-800';
      default: return 'text-gray-900';
    }
  }

  /**
   * Dismisses a notification element.
   * @param {HTMLElement} notificationElement - The element to dismiss.
   */
  dismiss(notificationElement) {
    if (notificationElement && notificationElement.parentNode) {
      notificationElement.remove();
    }
  }

  /**
   * Processes queued flash messages from server-rendered partials.
   * This is typically called on `turbo:load`.
   */
  processQueuedMessages() {
    // Check for messages embedded in a script tag (e.g., from Rails flash)
    const flashDataElement = document.getElementById('rails-flash-messages');

    if (flashDataElement && flashDataElement.textContent) {
      try {
        const messages = JSON.parse(flashDataElement.textContent);
        messages.forEach(msg => {
          this.show(msg.message, msg.type);
        });
      } catch (e) {
        console.error('Error parsing queued flash messages:', e);
      }
      flashDataElement.remove(); // Remove the script tag after processing
    }

    // Fallback for window._queuedFlashMessages (legacy support during transition)
    const legacyQueuedMessages = window._queuedFlashMessages || [];
    legacyQueuedMessages.forEach(eventData => {
      this.show(eventData.message, eventData.type);
    });
    window._queuedFlashMessages = []; // Clear legacy queue
  }

  /**
   * Ensures only a maximum number of notifications are displayed.
   * Removes the oldest notifications if the limit is exceeded.
   */
  cleanupOldNotifications() {
    const container = this.getOrCreateContainer();
    if (!container) {
      return; // Nothing to clean up if container doesn't exist
    }

    const existingNotifications = Array.from(container.children);
    if (existingNotifications.length >= this.maxNotifications) {
      const toRemoveCount = existingNotifications.length - this.maxNotifications + 1;
      for (let i = 0; i < toRemoveCount; i++) {
        this.dismiss(existingNotifications[i]);
      }
    }
  }
}

// Export a singleton instance for global access
window.AppNotifications = new NotificationService();

// Ensure the service is initialized on Turbo loads if it somehow gets lost
document.addEventListener('turbo:load', () => {
  if (!window.AppNotifications) {
    window.AppNotifications = new NotificationService();
  }
});
