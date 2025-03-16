import { Controller } from "@hotwired/stimulus"

// This controller provides UI feedback for file uploads
// It relies on Rails' built-in direct upload functionality
export default class extends Controller {
  static targets = ["input", "progress", "percentage", "statusText", "cancel", "signedId"]

  connect() {
    // Set default status text
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "No file selected"
    }
    
    // Listen for direct-upload events
    if (this.hasInputTarget) {
      this.setupDirectUploadHandlers()
    }
  }

  handleFileSelect(event) {
    const file = event.target.files[0]
    if (!file) {
      if (this.hasStatusTextTarget) {
        this.statusTextTarget.textContent = "No file selected"
      }
      return
    }

    // Update status text with file name and size
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = `Selected: ${file.name} (${this.formatFileSize(file.size)})`
    }
  }
  
  // Set up event handlers for Rails' direct upload
  setupDirectUploadHandlers() {
    this.element.addEventListener("direct-upload:initialize", this.initializeUpload.bind(this))
    this.element.addEventListener("direct-upload:start", this.startUpload.bind(this))
    this.element.addEventListener("direct-upload:progress", this.progressUpload.bind(this))
    this.element.addEventListener("direct-upload:error", this.errorUpload.bind(this))
    this.element.addEventListener("direct-upload:end", this.endUpload.bind(this))
  }
  
  initializeUpload(event) {
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "Preparing upload..."
    }
  }
  
  startUpload(event) {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove('hidden')
    }
    
    if (this.hasCancelTarget) {
      this.cancelTarget.classList.remove('hidden')
    }
  }
  
  progressUpload(event) {
    const { progress } = event.detail
    
    if (this.hasPercentageTarget) {
      this.percentageTarget.textContent = `${progress}%`
    }
    
    const progressBar = this.progressTarget.querySelector('[role="progressbar"]')
    if (progressBar) {
      progressBar.style.width = `${progress}%`
      progressBar.setAttribute('aria-valuenow', progress)
    }
  }
  
  errorUpload(event) {
    const { error } = event.detail
    
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = `Error: ${error}`
      this.statusTextTarget.classList.add('text-red-500')
    }
    
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add('hidden')
    }
    
    if (this.hasCancelTarget) {
      this.cancelTarget.classList.add('hidden')
    }
    
    console.error('Direct upload error:', error)
  }
  
  endUpload(event) {
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "Upload complete"
    }
    
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add('hidden')
    }
    
    if (this.hasCancelTarget) {
      this.cancelTarget.classList.add('hidden')
    }
  }

  handleDirectUploadEnd(event) {
    const { signedId } = event.detail.blob
    if (this.hasSignedIdTarget) {
      this.signedIdTarget.value = signedId
    }
  }
  
  cancelUpload(event) {
    // Reset file input
    if (this.hasInputTarget) {
      this.inputTarget.value = null
    }
    
    // Update UI
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "Upload canceled"
    }
    
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add('hidden')
    }
    
    if (this.hasCancelTarget) {
      this.cancelTarget.classList.add('hidden')
    }

    // Clear signed ID
    if (this.hasSignedIdTarget) {
      this.signedIdTarget.value = ''
    }
  }
  
  // Helper for formatting file sizes
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
}
