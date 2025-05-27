import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Only run in development
    if (!(process.env?.NODE_ENV === "development")) {
      return
    }

    console.log('Debug controller connected')
    
    // Store bound event handlers for cleanup
    this.boundClickHandler = this.handleClick.bind(this)
    this.boundErrorHandler = this.handleError.bind(this)
    
    // Set up event listeners
    document.addEventListener('click', this.boundClickHandler)
    window.addEventListener('error', this.boundErrorHandler)
    
    // Initial diagnostics
    this.logInitialState()
  }

  disconnect() {
    // Clean up event listeners
    if (this.boundClickHandler) {
      document.removeEventListener('click', this.boundClickHandler)
    }
    if (this.boundErrorHandler) {
      window.removeEventListener('error', this.boundErrorHandler)
    }
    
    console.log('Debug controller disconnected')
  }

  logInitialState() {
    // Check Chart.js availability
    if (typeof Chart !== 'undefined') {
      console.log('Chart.js is available:', Chart.version)
    } else {
      console.warn('Chart.js is not available!')
    }
    
    // Log Stimulus controllers (summary only)
    const controllers = document.querySelectorAll('[data-controller]')
    console.log(`Stimulus controllers found: ${controllers.length}`)
    
    // Log reports-specific elements if they exist
    const reportsButtons = document.querySelectorAll('[data-reports-toggle-target="button"]')
    const reportsPanels = document.querySelectorAll('[data-reports-toggle-target="panel"]')
    const chartControllers = document.querySelectorAll('[data-controller="reports-chart"]')
    
    if (reportsButtons.length > 0 || reportsPanels.length > 0 || chartControllers.length > 0) {
      console.log('Reports elements:', {
        buttons: reportsButtons.length,
        panels: reportsPanels.length,
        charts: chartControllers.length
      })
    }
  }

  handleClick(event) {
    // Only log clicks on reports-related elements to reduce noise
    const isReportsClick = event.target.closest('[data-reports-toggle-target="button"]') || 
                          event.target.closest('[data-action*="reports-toggle#toggle"]')
    
    if (isReportsClick) {
      console.log('Reports button clicked:', event.target)
      
      // Diagnostic checks after click
      setTimeout(() => {
        const panel = document.querySelector('[data-reports-toggle-target="panel"]')
        const chartControllers = document.querySelectorAll('[data-controller="reports-chart"]')
        const canvases = document.querySelectorAll('canvas')
        
        console.log('Post-click state:', {
          panelVisible: panel && !panel.classList.contains('hidden'),
          chartControllers: chartControllers.length,
          canvasElements: canvases.length
        })
      }, 100) // Reduced timeout for faster feedback
    }
  }

  handleError(event) {
    console.error('JavaScript error detected:', {
      message: event.error?.message || event.message,
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno
    })
  }
} 