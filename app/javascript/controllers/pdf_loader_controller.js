import { Controller } from "@hotwired/stimulus"

// This controller handles deferred loading of PDF files to ensure page components are fully initialized
export default class extends Controller {
  static targets = ["placeholder", "container"]
  
  connect() {
    console.log("PDF Loader controller connected")
  }
  
  // Load the PDF when user explicitly requests it
  loadPdf() {
    const pdfUrl = this.element.dataset.pdfUrl
    
    if (!pdfUrl) {
      console.error("PDF URL is missing")
      return
    }
    
    // Create iframe
    const iframe = document.createElement('iframe')
    iframe.src = pdfUrl
    iframe.type = "application/pdf"
    iframe.className = "w-full h-full"
    iframe.setAttribute('data-turbo', 'false')
    iframe.setAttribute('allow', 'fullscreen')
    
    // Add to container and show
    this.containerTarget.appendChild(iframe)
    this.containerTarget.classList.remove('hidden')
    this.placeholderTarget.classList.add('hidden')
    
    // Dispatch event that PDF loading has started
    this.element.dispatchEvent(new CustomEvent('pdf-loader:loaded'))
  }
}
