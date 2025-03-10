import { Controller } from "@hotwired/stimulus"

// Declare targets for type safety and better structure
export default class extends Controller {
  static targets = [ "container", "overlay" ]
  static values = { 
    id: String,
    preserveScroll: { type: Boolean, default: false }  // New value to track if we should preserve scroll
  }

  connect() {
    // Ensure modal is hidden on connect
    this.close()

    // Handle escape key
    this._handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._handleKeydown)
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
    iframes.forEach(iframe => {
      const originalSrc = iframe.getAttribute('data-original-src')
      console.log('Original src:', originalSrc)
      
      // Always set the src attribute, even if it's already set
      if (originalSrc) {
        console.log('Setting iframe src to:', originalSrc)
        
        // First clear the src attribute
        iframe.removeAttribute('src')
        
        // Force a reflow to ensure the browser recognizes the change
        void iframe.offsetWidth
        
        // Set the src attribute
        iframe.src = originalSrc
        
        // Add a load event listener to check if the iframe loaded correctly
        iframe.addEventListener('load', () => {
          console.log('Iframe loaded successfully:', iframe.src)
        })
        
        // Add an error event listener to check if there was an error loading the iframe
        iframe.addEventListener('error', (e) => {
          console.error('Error loading iframe:', e)
        })
      } else {
        console.log('Not setting iframe src because originalSrc is empty')
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
  
  // New method to clean up scrolling when returning from letter_opener
  cleanup() {
    console.log("Cleaning up modal scroll state")
    this.preserveScrollValue = false
    
    // Make sure we remove the overflow-hidden class
    // and do it with a slight delay to ensure any pending processes complete
    setTimeout(() => {
      document.body.classList.remove("overflow-hidden")
      console.log("Body scroll restored, overflow-hidden removed")
    }, 100)
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
