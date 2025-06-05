import { FetchRequest } from "@rails/request.js"

/**
 * Centralized Rails 8 request service
 * Handles common patterns: abort controllers, error handling, response parsing
 */
export class RailsRequestService {
  constructor() {
    this.activeRequests = new Map()
  }

  /**
   * Perform a Rails request with standard error handling
   * @param {Object} options Request configuration
   * @returns {Promise<Object>} Parsed response data
   */
  async perform({ 
    method = 'get',
    url,
    body = null,
    key = null, // Optional key for tracking/canceling specific requests
    signal = null,
    headers = {},
    onProgress = null
  }) {
    // Cancel existing request with same key if provided
    if (key && this.activeRequests.has(key)) {
      this.cancel(key)
    }

    // Create abort controller if not provided
    const controller = signal ? null : new AbortController()
    const finalSignal = signal || controller.signal

    if (key && controller) {
      this.activeRequests.set(key, controller)
    }

    try {
      const requestOptions = {
        signal: finalSignal,
        headers
      }

      if (body) {
        requestOptions.body = typeof body === 'string' ? body : JSON.stringify(body)
      }

      const request = new FetchRequest(method, url, requestOptions)
      
      // Add progress handler if provided
      if (onProgress && request.delegate) {
        request.delegate.fetchRequestWillStart = (fetchRequest) => {
          if (fetchRequest.request.body) {
            // Track upload progress if possible
            fetchRequest.request.addEventListener('progress', onProgress)
          }
        }
      }

      const response = await request.perform()

      if (!response.ok) {
        const errorData = await this.parseErrorResponse(response)
        throw new RequestError(errorData.error || `HTTP ${response.status}`, response.status, errorData)
      }

      const data = await this.parseSuccessResponse(response)
      
      // Clean up tracking
      if (key && this.activeRequests.has(key)) {
        this.activeRequests.delete(key)
      }

      return { success: true, data, response }

    } catch (error) {
      // Clean up tracking
      if (key && this.activeRequests.has(key)) {
        this.activeRequests.delete(key)
      }

      if (error.name === 'AbortError') {
        return { success: false, aborted: true }
      }

      throw error
    }
  }

  /**
   * Cancel a tracked request
   * @param {string} key Request key
   */
  cancel(key) {
    const controller = this.activeRequests.get(key)
    if (controller) {
      controller.abort()
      this.activeRequests.delete(key)
    }
  }

  /**
   * Cancel all active requests
   */
  cancelAll() {
    this.activeRequests.forEach(controller => controller.abort())
    this.activeRequests.clear()
  }

  /**
   * Parse successful response based on content type
   */
  async parseSuccessResponse(response) {
    const contentType = response.headers.get('content-type') || ''
    
    if (contentType.includes('application/json')) {
      return response.json()
    } else if (contentType.includes('text/html') || contentType.includes('text/vnd.turbo-stream.html')) {
      return response.text()
    } else {
      // Default to text
      return response.text()
    }
  }

  /**
   * Parse error response with fallback
   */
  async parseErrorResponse(response) {
    try {
      const contentType = response.headers.get('content-type') || ''
      if (contentType.includes('application/json')) {
        return await response.json()
      }
      return { error: `Server error: ${response.status}` }
    } catch (e) {
      return { error: `Server error: ${response.status}` }
    }
  }

  /**
   * Try to show flash message using global event system
   * @param {string} message - Message to display
   * @param {string} type - Message type (error, notice, alert)
   */
  tryShowFlash(message, type = 'error') {
    try {
      // Dispatch global event for flash controller to listen to
      document.dispatchEvent(new CustomEvent('rails-request:flash', {
        detail: { message, type }
      }))
      return true
    } catch (error) {
      // Silently fail - flash integration is optional
      if (process.env.NODE_ENV !== 'production') {
        console.debug('Flash event dispatch failed:', error)
      }
      return false
    }
  }

  /**
   * Enhanced error handling with flash integration
   * @param {Error} error - Error to handle
   * @param {Object} options - Error handling options
   */
  handleError(error, { showFlash = true, logError = true } = {}) {
    if (logError) {
      console.error('Rails request error:', error)
    }

    // Try to show user-friendly flash message
    if (showFlash && error.message) {
      const shown = this.tryShowFlash(error.message, 'error')
      
      // Fallback to console for development if flash not available
      if (!shown && process.env.NODE_ENV !== 'production') {
        console.warn('Flash message not shown (no flash controller):', error.message)
      }
    }
  }
}

/**
 * Custom error class for request errors
 */
export class RequestError extends Error {
  constructor(message, status, data = {}) {
    super(message)
    this.name = 'RequestError'
    this.status = status
    this.data = data
  }
}

// Export singleton instance
export const railsRequest = new RailsRequestService() 