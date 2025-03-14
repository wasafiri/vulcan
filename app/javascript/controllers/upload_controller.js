import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage/src/direct_upload"

export default class extends Controller {
  static targets = [ "input", "progress", "submit", "cancel", "statusText", "percentage", "signedId" ]

  connect() {
    this.progressBar = this.progressTarget.querySelector("[role='progressbar']")
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
    }
    this.hideProgress()
  }

  fileSelected(event) {
    const file = event.target.files[0]
    if (!file) return

    // Update the status text to show the selected file
    this.updateStatusText(`Selected: ${file.name} (${this.formatFileSize(file.size)})`)
    
    // No longer start uploading immediately - Rails will handle this on form submit
    // Instead, show a success message and enable the form
    this.enableSubmit()
  }
  
  // Optional helper function for formatting file sizes
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  updateProgress(event) {
    if (event.lengthComputable) {
      const progress = Math.round((event.loaded / event.total) * 100)
      this.progressBar.style.width = `${progress}%`
      this.progressBar.setAttribute("aria-valuenow", progress)
      
      if (this.hasPercentageTarget) {
        this.percentageTarget.textContent = `${progress}%`
      }
      
      // Announce progress to screen readers
      const announcement = document.createElement("div")
      announcement.setAttribute("aria-live", "polite")
      announcement.textContent = `Upload progress: ${progress}%`
      this.element.appendChild(announcement)
      
      // Remove announcement after it's been read
      setTimeout(() => announcement.remove(), 1000)
    }
  }

  handleSuccess(blob) {
    // Update the hidden field with the signed_id
    if (this.hasSignedIdTarget) {
      this.signedIdTarget.value = blob.signed_id
    } else {
      // Fallback to creating a new hidden field if no target exists
      const hiddenField = document.createElement('input')
      hiddenField.setAttribute("type", "hidden")
      hiddenField.setAttribute("value", blob.signed_id)
      hiddenField.name = this.inputTarget.name
      this.element.appendChild(hiddenField)
    }

    this.enableSubmit()
    this.hideProgress()
    this.hideCancel()
    this.updateStatusText(`File uploaded successfully`)
  }

  handleError(error) {
    // Show error message
    this.updateStatusText(`Error uploading file: ${error.message || "Unknown error"}`)

    this.enableSubmit()
    this.hideProgress()
    this.hideCancel()
    
    console.error("Upload error:", error)
  }

  cancelUpload() {
    if (this.currentXHR) {
      this.currentXHR.abort()
      this.currentXHR = null
    }
    
    this.enableSubmit()
    this.hideProgress()
    this.hideCancel()
    this.inputTarget.value = ""
    this.updateStatusText("Upload canceled")
  }

  updateStatusText(text) {
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = text
    }
  }

  showProgress() {
    this.progressTarget.classList.remove("hidden")
  }

  hideProgress() {
    this.progressTarget.classList.add("hidden")
  }

  showCancel() {
    this.cancelTarget.classList.remove("hidden")
  }

  hideCancel() {
    this.cancelTarget.classList.add("hidden")
  }

  enableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
    }
  }

  disableSubmit() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
    }
  }
}
