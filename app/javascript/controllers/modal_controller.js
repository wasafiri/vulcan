import { Controller } from "@hotwired/stimulus"

// Declare targets for type safety and better structure
export default class extends Controller {
  static targets = [ "container", "overlay" ]
  static values = { 
    id: String,
    preserveScroll: { type: Boolean, default: false }  // New value to track if we should preserve scroll
  }

  connect() {
    console.log('Modal controller connected with ID:', this.element.id)
    console.debug('Modal controller targets:', this.targets)
    
    // Ensure modal is hidden on connect
    this.close()

    // Handle escape key
    this._handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleKeydown)
    
    // Add Turbo form submission event listeners
    this._handleTurboSubmitEnd = this.handleTurboSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-end", this._handleTurboSubmitEnd)
    
    // Add listener for our custom form submit event from rejection form controller
    this._handleTurboFormSubmit = this.handleTurboFormSubmit.bind(this)
    document.addEventListener("turbo-form-submit", this._handleTurboFormSubmit)
    
    // Add a safety timeout to ensure body scroll is restored if other mechanisms fail
    this._setupScrollSafetyTimeout()
    
    console.log('Modal controller initialization complete')
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleKeydown)
    document.removeEventListener("turbo:submit-end", this._handleTurboSubmitEnd)
    document.removeEventListener("turbo-form-submit", this._handleTurboFormSubmit)
    if (this._scrollSafetyTimeout) {
      clearTimeout(this._scrollSafetyTimeout)
    }
    this.cleanup()
  }

  open(event) {
    console.log('Modal open called', event)
    // If a modal ID is provided in the event, use that to find the modal
    const modalId = event?.currentTarget?.dataset?.modalId
    console.log('Modal ID:', modalId)
    let modalElement = null
    
    if (modalId) {
      modalElement = document.getElementById(modalId)
      console.log('Found modal element by ID:', modalElement)
      if (modalElement) {
        modalElement.classList.remove("hidden")
        document.body.classList.add("overflow-hidden")
        
        // Handle iframes with data-original-src
        this._loadIframes(modalElement)
        
        // Focus first input
        const firstInput = modalElement.querySelector("input, textarea")
        if (firstInput) {
          firstInput.focus()
        }
        return
      }
    }
    
    // Default behavior if no modal ID is provided or modal not found
    console.log('Using default behavior with containerTarget')
    modalElement = this.containerTarget
    modalElement.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    
    // Handle iframes with data-original-src
    this._loadIframes(modalElement)

    // Focus first input
    const firstInput = modalElement.querySelector("input, textarea")
    if (firstInput) {
      firstInput.focus()
    }
  }
  
  /**
   * Helper method to load iframes with data-original-src
   * 
   * IMPORTANT: This method is critical for PDF previews in modals to work correctly.
   * Previous implementations had issues where the iframe's src attribute wasn't being
   * set correctly when the modal was opened, resulting in blank PDF previews.
   * 
   * The current implementation:
   * 1. Forcibly clears the src attribute first
   * 2. Forces a browser reflow to ensure the change is recognized
   * 3. Sets the src attribute to the original source
   * 4. Adds event listeners to track successful loading or errors
   * 
   * DO NOT MODIFY THIS METHOD without thorough testing of PDF previews in modals.
   * Changes here have repeatedly broken PDF previews in the past.
   */
  _loadIframes(element) {
    console.log('Loading iframes in element:', element)
    const iframes = element.querySelectorAll('iframe[data-original-src]')
    console.log('Found iframes with data-original-src:', iframes.length)
    
    if (iframes.length === 0) {
      console.log('No iframes found with data-original-src attribute')
      return
    }
    
    iframes.forEach(iframe => {
      // Check if the iframe has already been loaded
      const isLoaded = iframe.getAttribute('data-pdf-loaded') === 'true'
      if (isLoaded) {
        console.log('Iframe already loaded, skipping:', iframe.src)
        return
      }
      
      const originalSrc = iframe.getAttribute('data-original-src')
      console.log('Original src:', originalSrc)
      
      // Verify we have a valid originalSrc
      if (!originalSrc) {
        console.error('Empty data-original-src attribute on iframe, cannot load PDF')
        return
      }
      
      try {
        console.log('Setting iframe src to:', originalSrc)
        
        // First clear the src attribute
        iframe.removeAttribute('src')
        
        // Force a reflow to ensure the browser recognizes the change
        void iframe.offsetWidth
        
        // Set the src attribute
        iframe.src = originalSrc
        
        // Mark as loading
        iframe.setAttribute('data-pdf-loading', 'true')
        
        // Add a load event listener to check if the iframe loaded correctly
        iframe.addEventListener('load', () => {
          console.log('Iframe loaded successfully:', iframe.src)
          // Mark as successfully loaded
          iframe.setAttribute('data-pdf-loaded', 'true')
          iframe.removeAttribute('data-pdf-loading')
        })
        
        // Add an error event listener to check if there was an error loading the iframe
        iframe.addEventListener('error', (e) => {
          console.error('Error loading iframe:', e)
          iframe.removeAttribute('data-pdf-loading')
          
          // Try to provide more helpful error information
          const errorContainer = document.createElement('div')
          errorContainer.className = 'p-4 bg-red-50 border border-red-100 rounded my-2'
          errorContainer.innerHTML = `
            <p class="text-red-800 font-medium">Error loading PDF</p>
            <p class="text-red-600 text-sm">There was a problem loading the PDF. Try opening it directly: 
              <a href="${originalSrc}" target="_blank" class="underline">Open PDF</a>
            </p>
          `
          
          // Insert the error message before the iframe
          iframe.parentNode.insertBefore(errorContainer, iframe)
        })
      } catch (err) {
        console.error('Exception while setting up PDF iframe:', err)
      }
    })
  }

  close(event) {
    event?.preventDefault()
    
    // Mark modals as closed first
    const modalElement = event?.currentTarget?.closest('[data-modal-target="container"]')
    if (modalElement) {
      console.log("Closing specific modal via event")
      modalElement.classList.add("hidden")
    } else {
      console.log("Closing default modal")
      this.containerTarget.classList.add("hidden")
    }
    
    // Check if any modals are still visible
    const anyVisibleModals = document.querySelectorAll('[data-modal-target="container"]:not(.hidden)').length > 0;
    console.log("Any visible modals:", anyVisibleModals)
    
    // Only remove overflow-hidden if we're not preserving scroll AND no other modals are visible
    if (!this.preserveScrollValue && !anyVisibleModals) {
      console.log("Removing overflow-hidden from body")
      document.body.classList.remove("overflow-hidden")
    } else {
      console.log("Not removing overflow-hidden. preserveScroll:", this.preserveScrollValue)
    }
  }
  
  // New method to handle form submissions that might open new windows
  handleFormSubmission(event) {
    const form = event.target
    const opensNewWindow = form.dataset.opensNewWindow === 'true'
    
    if (opensNewWindow) {
      // Set preserveScroll to true to maintain overflow-hidden when modal closes
      this.preserveScrollValue = true
      
      // Add a visibility change listener to restore scroll when tab focus returns
      document.addEventListener("visibilitychange", () => {
        if (!document.hidden) {
          // First close any open modals
          document.querySelectorAll('[data-modal-target="container"]').forEach(modal => {
            modal.classList.add('hidden');
          });
          
          // Then clean up
          this.cleanup()
        }
      }, { once: true }) // Only run this once
    } else {
      // Normal form submission, no need to preserve scroll
      this.preserveScrollValue = false
    }
  }
  
  // Enhanced method to clean up scrolling and modal state
  cleanup() {
    console.log("Cleaning up modal scroll state")
    
    // Reset scroll preservation flag regardless of current value
    this.preserveScrollValue = false
    
    // Immediately remove overflow-hidden class
    document.body.classList.remove("overflow-hidden")
    console.log("Body scroll restored, overflow-hidden removed")
    
    // Ensure all modals are hidden
    document.querySelectorAll('[data-modal-target="container"]').forEach(modal => {
      modal.classList.add('hidden')
      console.log("Hidden modal:", modal.id || 'unnamed modal')
    })
    
    // Set up safety timeout again in case we need it
    this._setupScrollSafetyTimeout()
  }
  
  // Setup a safety timeout to ensure body scroll is restored
  _setupScrollSafetyTimeout() {
    // Clear any existing timeout
    if (this._scrollSafetyTimeout) {
      clearTimeout(this._scrollSafetyTimeout)
    }
    
    // Set a new timeout that will ensure body scroll is restored
    // even if other mechanisms fail
    this._scrollSafetyTimeout = setTimeout(() => {
      // Only run if overflow-hidden is still present
      if (document.body.classList.contains("overflow-hidden")) {
        console.warn("Safety timeout triggered: overflow-hidden still present on body")
        document.body.classList.remove("overflow-hidden")
      }
    }, 2000) // 2 seconds should be plenty of time for normal operations to complete
  }
  
  // Handle custom turbo-form-submit event from rejection form
  handleTurboFormSubmit(event) {
    console.log("Custom turbo-form-submit event received from rejection form")
    
    // Mark that we need to restore scroll
    this._formSubmissionInProgress = true;
    
    // Immediately ensure all modals are hidden to prevent stacking issues
    document.querySelectorAll('[data-modal-target="container"]').forEach(modal => {
      modal.classList.add('hidden');
    });
    
    // First timer that runs quickly to catch immediate responses
    setTimeout(() => {
      console.log("First scroll restoration check")
      // Force cleanup body overflow regardless of submission state
      document.body.classList.remove("overflow-hidden")
    }, 300);
    
    // Second timer with longer delay as a fallback
    setTimeout(() => {
      console.log("Second scroll restoration check")
      if (this._formSubmissionInProgress) {
        console.log("Form submission still in progress, force-restoring body scroll")
        document.body.classList.remove("overflow-hidden")
        this._formSubmissionInProgress = false;
      }
      
      // Always ensure document body is scrollable
      if (document.body.classList.contains("overflow-hidden")) {
        console.log("overflow-hidden still present, removing")
        document.body.classList.remove("overflow-hidden")
      }
    }, 1000); // Increased delay to handle slower responses
    
    // Add a visibility change listener as an extra safety measure
    // This catches cases where the user switches tabs during submission
    const visibilityListener = () => {
      console.log("Visibility changed - cleaning up modal state")
      document.body.classList.remove("overflow-hidden")
      document.removeEventListener("visibilitychange", visibilityListener)
    };
    document.addEventListener("visibilitychange", visibilityListener, { once: true })
  }
  
  // Handle Turbo form submissions
  handleTurboSubmitEnd(event) {
    // Check if the form that was submitted belongs to a modal
    const form = event.detail?.formSubmission?.formElement
    if (form && form.closest('[data-modal-target="container"]')) {
      console.log("Turbo form submission complete in modal, ensuring body scroll is restored")
      
      // Mark that a form submission has completed
      this._formSubmissionInProgress = false;
      
      // Immediately hide all modals to prevent stacking issues
      document.querySelectorAll('[data-modal-target="container"]').forEach(modal => {
        modal.classList.add('hidden');
      });
      
      // Wait a short moment to allow Turbo to process the response
      setTimeout(() => {
        // Check if we should restore scroll
        const shouldRestoreScroll = !this.preserveScrollValue
        
        if (shouldRestoreScroll) {
          console.log("Restoring body scroll after Turbo form submission")
          document.body.classList.remove("overflow-hidden")
        }
        
        // Always check if overflow-hidden is still present and remove it as a safety measure
        if (document.body.classList.contains("overflow-hidden")) {
          console.log("overflow-hidden still present, removing")
          document.body.classList.remove("overflow-hidden")
        }
      }, 250) // Increased from 100ms for more reliable cleanup
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  // Prevent clicks inside modal from closing it
  preventClose(event) {
    event.stopPropagation()
  }

  // Handle form submission
  handleSubmit(event) {
    const form = event.target
    const isValid = form.checkValidity()
    const opensNewWindow = form.dataset.opensNewWindow === 'true'

    if (!isValid) {
      event.preventDefault()
      // Show validation messages
      form.reportValidity()
    } else if (!opensNewWindow) {
      // Only close modal directly if it doesn't open a new window
      this.close()
    }
    // If it opens a new window, handleFormSubmission will be called separately
  }
}
