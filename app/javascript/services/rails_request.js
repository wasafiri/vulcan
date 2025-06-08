import { FetchRequest } from "@rails/request.js"

/**
 * Centralized Rails 8 request service
 * Handles common patterns: abort controllers, error handling, response parsing
 */
export class RailsRequestService {
  constructor() {
    this.activeRequests = new Map()
    this.setupUnhandledRejectionHandler()
  }

  /**
   * Set up global handler to catch specific @rails/request.js errors that escape try/catch blocks
   */
  setupUnhandledRejectionHandler() {
    if (typeof window !== 'undefined') {
      window.addEventListener('unhandledrejection', (event) => {
        const error = event.reason
        // Check if this is the specific @rails/request.js error we want to suppress
        if (error && error.message && error.message.includes('Expected a JSON response but got "text/html" instead')) {
          if (process.env.NODE_ENV !== 'production') {
            console.debug('RailsRequestService: Suppressed unhandled @rails/request.js JSON parsing error')
          }
          event.preventDefault() // Prevent the error from being logged to console
        }
      })
    }
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
    const contentType = response.headers?.get('content-type') || ''
    
    // Debug logging for development
    if (process.env.NODE_ENV !== 'production') {
      console.debug('parseSuccessResponse:', {
        contentType,
        hasJsonProperty: !!response.json,
        jsonIsFunction: typeof response.json === 'function',
        hasTextProperty: !!response.text,
        textIsFunction: typeof response.text === 'function'
      })
    }
    
    // For HTML responses, always use text parsing
    if (contentType.includes('text/html') || contentType.includes('text/vnd.turbo-stream.html')) {
      // @rails/request.js sometimes pre-processes HTML responses incorrectly, causing conflicts
      // Try each method carefully and suppress specific errors
      
      // Method 1: Try original response if available
      const originalResponse = response.response || response
      if (typeof originalResponse.text === 'function') {
        try {
          return await originalResponse.text()
        } catch (error) {
          if (process.env.NODE_ENV !== 'production') {
            console.debug('parseSuccessResponse: originalResponse.text() failed:', error.message)
          }
        }
      }
      
      // Method 2: Try standard fetch response
      if (typeof response.text === 'function') {
        try {
          return await response.text()
        } catch (error) {
          if (process.env.NODE_ENV !== 'production') {
            console.debug('parseSuccessResponse: response.text() failed:', error.message)
          }
        }
      }
      
      // Method 3: Try pre-processed promise, but catch and suppress @rails/request.js errors
      if (response.text && typeof response.text !== 'function') {
        // Wrap the promise to handle unhandled rejections
        const textPromise = Promise.resolve(response.text).catch(error => {
          // Specifically catch and suppress the @rails/request.js JSON parsing error
          if (error.message && error.message.includes('Expected a JSON response')) {
            if (process.env.NODE_ENV !== 'production') {
              console.debug('parseSuccessResponse: Suppressed @rails/request.js JSON parsing error for HTML response')
            }
            // Return empty string since we can't get the actual content
            return ''
          }
          // Re-throw other errors
          throw error
        })
        
        try {
          return await textPromise
        } catch (error) {
          if (process.env.NODE_ENV !== 'production') {
            console.debug('parseSuccessResponse: textPromise failed:', error.message)
          }
          return ''
        }
      }
      
      // Fallback for HTML responses
      return ''
    }
    
    // For JSON responses
    if (contentType.includes('application/json')) {
      // Check if @rails/request.js already resolved json
      if (response.json && typeof response.json !== 'function') {
        try {
          return await response.json
        } catch (error) {
          console.warn('parseSuccessResponse: pre-processed JSON failed:', error.message)
          return {}
        }
      }
      // Use standard fetch json() method
      try {
        return await response.json()
      } catch (error) {
        console.warn('parseSuccessResponse: response.json() failed:', error.message)
        return {}
      }
    }
    
    // Default to text for unknown content types
    if (response.text && typeof response.text !== 'function') {
      try {
        return await response.text
      } catch (error) {
        console.warn('parseSuccessResponse: pre-processed text failed:', error.message)
        return ''
      }
    }
    
    try {
      return await response.text()
    } catch (error) {
      console.warn('parseSuccessResponse: response.text() fallback failed:', error.message)
      return ''
    }
  }

  /**
   * Parse error response with fallback
   */
  async parseErrorResponse(response) {
    try {
      // Check if response.json is already a Promise (from @rails/request.js)
      if (response.json && typeof response.json !== 'function') {
        // If response.json is already a Promise, await it
        return await response.json
      }
      
      // Standard fetch Response object handling
      const contentType = response.headers?.get('content-type') || ''
      if (contentType.includes('application/json')) {
        return await response.json()
      }
      return { error: `Server error: ${response.status}` }
    } catch (e) {
      return { error: `Server error: ${response.status}` }
    }
  }

  /**
   * Try to show flash message using the new global AppNotifications service.
   * @param {string} message - Message to display
   * @param {string} type - Message type (success, error, warning, info)
   */
  tryShowFlash(message, type = 'error') {
    if (window.AppNotifications && typeof window.AppNotifications.show === 'function') {
      window.AppNotifications.show(message, type);
      return true;
    } else {
      // Fallback to console if AppNotifications is not available (e.g., during development or if not loaded)
      if (process.env.NODE_ENV !== 'production') {
        console.warn('AppNotifications service not available to show flash message:', message, type);
      }
      return false;
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
