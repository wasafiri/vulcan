import { Controller } from "@hotwired/stimulus"
import { setVisible } from "../utils/visibility"

// Declare targets and values for better structure
export default class extends Controller {
  static targets = ["container", "overlay"]
  static values = {
    id: String,
    preserveScroll: { type: Boolean, default: false }
  }

  connect() {
    // Fail fast if the container target is missing
    if (!this.hasContainerTarget) {
      if (process.env.NODE_ENV !== 'production') {
        console.error("ModalController: missing container target")
      }
      return
    }

    if (process.env.NODE_ENV !== 'production') {
      console.log("Modal controller connected with ID:", this.element.id)
      console.debug("Modal controller targets:", this.targets)
    }

    // Ensure modal is hidden on connect
    this.close()

    // Bind and register document-level listeners
    this._handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this._handleKeydown)

    this._handleTurboSubmitEnd = this.handleTurboSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-end", this._handleTurboSubmitEnd)

    this._handleTurboFormSubmit = this.handleTurboFormSubmit.bind(this)
    document.addEventListener("turbo-form-submit", this._handleTurboFormSubmit)

    // Safety timeout to restore scroll if needed
    this._setupScrollSafetyTimeout()

    if (process.env.NODE_ENV !== 'production') {
      console.log("Modal controller initialization complete")
    }
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
    // Determine which modal element to show
    const modalId = event?.currentTarget?.dataset?.modalId
    const modalElement = modalId
      ? document.getElementById(modalId)
      : this.containerTarget

    if (!modalElement) {
      console.error("ModalController: could not find modal element", modalId)
      return
    }

    this._showModal(modalElement)
  }

  _showModal(element) {
    // Reset PDF loaded state so that PDFs can be reloaded
    element.querySelectorAll('iframe[data-original-src]').forEach((iframe) => {
      iframe.removeAttribute("data-pdf-loaded")
    })
    // Show modal, lock scroll, load PDFs, focus first input
    setVisible(element, true)
    this._lockScroll()
    this._loadIframes(element)
    const firstInput = element.querySelector("input, textarea")
    firstInput?.focus()
  }

  _lockScroll() {
    document.body.classList.add("overflow-hidden")
  }

  _unlockScroll() {
    document.body.classList.remove("overflow-hidden")
  }

  _loadIframes(element) {
    if (process.env.NODE_ENV !== 'production') {
      console.log("Loading iframes in element:", element)
      console.log("Modal ID:", element.id)
    }
    const iframes = element.querySelectorAll('iframe[data-original-src]')
    if (process.env.NODE_ENV !== 'production') {
      console.log("Found iframes:", iframes.length)
    }
    
    iframes.forEach((iframe, index) => {
      if (process.env.NODE_ENV !== 'production') {
        console.log(`Processing iframe ${index} in ${element.id}`)
      }
      
      const already = iframe.getAttribute("data-pdf-loaded") === "true"
      if (already) {
        if (process.env.NODE_ENV !== 'production') {
          console.log(`Iframe ${index} already loaded, skipping`)
        }
        return
      }

      const originalSrc = iframe.getAttribute("data-original-src")
      if (!originalSrc) {
        console.error(`Iframe ${index}: Empty data-original-src on iframe`)
        return
      }
      
      if (process.env.NODE_ENV !== 'production') {
        console.log(`Iframe ${index} original src:`, originalSrc)
      }

      try {
        // Check current src
        const currentSrc = iframe.getAttribute("src") 
        if (process.env.NODE_ENV !== 'production') {
          console.log(`Iframe ${index} current src:`, currentSrc)
          console.log(`Setting src for iframe ${index} in ${element.id} to:`, originalSrc)
          
          // DEBUG: Log the proof type based on modal ID
          if (element.id === 'incomeProofReviewModal') {
            console.log('INCOME PROOF PDF LOADING')
          } else if (element.id === 'residencyProofReviewModal') {
            console.log('RESIDENCY PROOF PDF LOADING')
          } else if (element.id === 'medicalCertificationReviewModal') {
            console.log('MEDICAL CERTIFICATION PDF LOADING')
          }
        }
        
        // Force refresh by replacing iframe with a new one
        const parent = iframe.parentNode
        const newIframe = iframe.cloneNode(true)
        newIframe.src = originalSrc + '&t=' + new Date().getTime() // Add timestamp to bust cache
        
        newIframe.setAttribute("data-pdf-loading", "true")

        newIframe.addEventListener("load", () => {
          newIframe.setAttribute("data-pdf-loaded", "true")
          newIframe.removeAttribute("data-pdf-loading")
        })
        newIframe.addEventListener("error", e => {
          console.error("Error loading iframe:", e)
          newIframe.removeAttribute("data-pdf-loading")
          const errorContainer = document.createElement("div")
          errorContainer.className = "p-4 bg-red-50 border border-red-100 rounded my-2"
          errorContainer.innerHTML = `
            <p class="text-red-800 font-medium">Error loading PDF</p>
            <p class="text-red-600 text-sm">
              There was a problem loading the PDF. Try opening it directly:
              <a href="${originalSrc}" target="_blank" class="underline">Open PDF</a>
            </p>
          `
          newIframe.parentNode.insertBefore(errorContainer, newIframe)
        })
        
        // Replace after event listeners are attached
        parent.replaceChild(newIframe, iframe)
      } catch (err) {
        console.error("Exception in _loadIframes:", err)
      }
    })
  }

  close(event) {
    event?.preventDefault()

    const modalElement =
      event?.currentTarget?.closest('[data-modal-target="container"]') ||
      this.containerTarget

    if (modalElement) {
      setVisible(modalElement, false)
      modalElement.querySelectorAll('iframe[data-original-src]').forEach((iframe) => {
        iframe.removeAttribute("data-pdf-loaded")
      })
    }

    // Only remove overflow-hidden if no other modals are visible
    const anyVisible = this.element.querySelectorAll(
      '[data-modal-target="container"]:not(.hidden)'
    ).length > 0

    if (!this.preserveScrollValue && !anyVisible) {
      this._unlockScroll()
    }
  }

  handleFormSubmission(event) {
    const form = event.target
    const opensNewWindow = form.dataset.opensNewWindow === "true"

    if (opensNewWindow) {
      this.preserveScrollValue = true
      document.addEventListener(
        "visibilitychange",
        () => { this.cleanup() },
        { once: true }
      )
    } else {
      this.preserveScrollValue = false
    }
  }

  cleanup() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("Cleaning up modal scroll state")
    }
    this.preserveScrollValue = false
    this._unlockScroll()
    this.element
      .querySelectorAll('[data-modal-target="container"]')
      .forEach(modal => setVisible(modal, false))
    this._setupScrollSafetyTimeout()
  }

  _setupScrollSafetyTimeout() {
    clearTimeout(this._scrollSafetyTimeout)
    this._scrollSafetyTimeout = setTimeout(() => {
      if (document.body.classList.contains("overflow-hidden")) {
        if (process.env.NODE_ENV !== 'production') {
          console.warn("Safety timeout: restoring scroll")
        }
        this._unlockScroll()
      }
    }, 2000)
  }

  handleTurboFormSubmit(event) {
    if (process.env.NODE_ENV !== 'production') {
      console.log("Custom turbo-form-submit received")
    }
    this._formSubmissionInProgress = true
    this.element
      .querySelectorAll('[data-modal-target="container"]')
      .forEach(modal => setVisible(modal, false))

    setTimeout(() => {
      this._unlockScroll()
    }, 300)

    setTimeout(() => {
      if (this._formSubmissionInProgress) {
        this._unlockScroll()
        this._formSubmissionInProgress = false
      }
      if (document.body.classList.contains("overflow-hidden")) {
        this._unlockScroll()
      }
    }, 1000)

    const onVisible = () => {
      if (process.env.NODE_ENV !== 'production') {
        console.log("Visibility change: cleaning up")
      }
      this._unlockScroll()
      document.removeEventListener("visibilitychange", onVisible)
    }
    document.addEventListener("visibilitychange", onVisible, { once: true })
  }

  handleTurboSubmitEnd(event) {
    const form = event.detail?.formSubmission?.formElement
    if (form?.closest('[data-modal-target="container"]')) {
      if (process.env.NODE_ENV !== 'production') {
        console.log("Turbo form submission in modal finished")
      }
      this._formSubmissionInProgress = false
      this.element
        .querySelectorAll('[data-modal-target="container"]')
        .forEach(modal => setVisible(modal, false))

      setTimeout(() => {
        if (!this.preserveScrollValue) {
          this._unlockScroll()
        }
        if (document.body.classList.contains("overflow-hidden")) {
          this._unlockScroll()
        }
      }, 250)
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  preventClose(event) {
    event.stopPropagation()
  }

  handleSubmit(event) {
    const form = event.target
    const isValid = form.checkValidity()
    const opensNewWindow = form.dataset.opensNewWindow === "true"

    if (!isValid) {
      event.preventDefault()
      form.reportValidity()
    } else if (!opensNewWindow) {
      this.close()
    }
  }
}
