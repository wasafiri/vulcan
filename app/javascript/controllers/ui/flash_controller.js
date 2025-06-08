import { Controller } from "@hotwired/stimulus"

/**
 * Flash Controller
 * 
 * Provides centralized toast notification functionality.
 * Replaces ad-hoc document.body.appendChild patterns with standardized styling.
 */
export default class extends Controller {
  connect() {
    // This controller now primarily acts as a bridge for legacy flash messages
    // and delegates to the new global AppNotifications service.
    // It also processes any queued messages from server-rendered partials.
    this.processQueuedMessages();
  }

  /**
   * Handle flash events from RailsRequestService.
   * This method now delegates to the new global AppNotifications service.
   * @param {CustomEvent} event - The flash event
   */
  handleFlashEvent(event) {
    const { message, type } = event.detail;
    window.AppNotifications.show(message, type);
  }

  /**
   * Show a success message. Delegates to AppNotifications.
   * @param {string} message The message to display
   */
  showSuccess(message) {
    window.AppNotifications.showSuccess(message);
  }

  /**
   * Show an error message. Delegates to AppNotifications.
   * @param {string} message The message to display
   */
  showError(message) {
    window.AppNotifications.showError(message);
  }

  /**
   * Show a general info message. Delegates to AppNotifications.
   * @param {string} message The message to display
   */
  showInfo(message) {
    window.AppNotifications.showInfo(message);
  }

  /**
   * Show a flash message. Delegates to AppNotifications.
   * This method is now a wrapper for the new service.
   * @param {string} message The message to display
   * @param {string} type The type of message (success, error, info)
   */
  show(message, type = 'info') {
    window.AppNotifications.show(message, type);
  }

  /**
   * This controller no longer directly creates or manages notification elements.
   * All such functionality has been moved to `app/javascript/services/notification_service.js`.
   * The methods below are retained only to satisfy existing calls during the transition phase.
   */

  // These methods are now effectively no-ops or wrappers,
  // as their functionality is handled by window.AppNotifications.
  createNotification(message, type) { /* no-op */ }
  getNotificationClasses(type) { return ''; }
  getIcon(type) { return ''; }
  getLabel(type) { return ''; }
  cleanupOldNotifications() { /* no-op */ }
  createCloseButton() { return document.createElement('button'); }
}
