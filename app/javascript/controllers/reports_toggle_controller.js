import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "button"]

  connect() {
    console.log("Reports toggle controller connected")
    console.log("Button targets count:", this.buttonTargets.length)
    console.log("Has panel target:", this.hasPanelTarget)
    
    // Initialize button states
    this.buttonTargets.forEach(button => {
      console.log("Setting button aria-expanded to false:", button)
      button.setAttribute('aria-expanded', 'false')
      
      // Set initial button text if it's the main toggle button
      if (button.textContent.trim() === 'System Reports') {
        button.setAttribute('data-original-text', 'System Reports')
      }
    })
  }

  toggle(event) {
    console.log("Toggle method called", event)
    
    if (!this.hasPanelTarget) {
      console.error("Panel target not found")
      return
    }
    
    const isHidden = this.panelTarget.classList.contains('hidden')
    console.log("Panel is currently hidden:", isHidden)
    
    // Toggle the hidden class
    this.panelTarget.classList.toggle('hidden')
    console.log("Toggled panel visibility")
    
    // If we're showing the panel, dispatch a custom event to notify charts
    if (isHidden) {
      console.log("Panel is now visible, dispatching visibility-changed event")
      // Use a small delay to ensure the DOM has updated
      setTimeout(() => {
        const visibilityEvent = new CustomEvent('visibility-changed', { 
          bubbles: true,
          detail: { visible: true }
        })
        this.panelTarget.dispatchEvent(visibilityEvent)
      }, 50)
    }
    
    // Update button state for accessibility
    if (event && event.currentTarget) {
      event.currentTarget.setAttribute('aria-expanded', isHidden ? 'true' : 'false')
      
      // Update button text if it's the main toggle button
      if (event.currentTarget.hasAttribute('data-original-text')) {
        const originalText = event.currentTarget.getAttribute('data-original-text')
        
        // If the button has a span child, update its text
        const buttonTextSpan = event.currentTarget.querySelector('span')
        if (buttonTextSpan) {
          buttonTextSpan.textContent = isHidden ? 'Hide Reports' : originalText
        }
      }
    }
    
    // Update all button targets if available
    if (this.hasButtonTarget) {
      this.buttonTargets.forEach(button => {
        button.setAttribute('aria-expanded', isHidden ? 'true' : 'false')
        
        // Skip the button that triggered the event
        if (event && event.currentTarget === button) {
          return
        }
        
        // Update other buttons' text if they have the data attribute
        if (button.hasAttribute('data-original-text')) {
          const originalText = button.getAttribute('data-original-text')
          
          // If the button has a span child, update its text
          const buttonTextSpan = button.querySelector('span')
          if (buttonTextSpan) {
            buttonTextSpan.textContent = isHidden ? 'Hide Reports' : originalText
          }
        }
      })
    }
  }
}
