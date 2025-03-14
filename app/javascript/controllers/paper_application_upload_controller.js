import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage/src/direct_upload"

// This controller handles direct file uploads for paper applications
// It is a modified version of the constituent portal upload controller
// that has been adapted for admin use.
export default class extends Controller {
  static targets = [ "input", "progress", "submit", "cancel", "statusText" ]

  connect() {
    this.progressBar = this.progressTarget.querySelector("[role='progressbar']")
    this.submitTarget.disabled = false
    this.hideProgress()
    
    // Set default status text
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "No file selected"
    }
  }

  handleFileSelect(event) {
    const file = event.target.files[0]
    if (!file) return

    // Update status text
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = `Selected: ${file.name} (${this.formatFileSize(file.size)})`
    }

    this.showProgress()
    this.disableSubmit()
    this.showCancel()

    const url = this.inputTarget.dataset.directUploadUrl
    const upload = new DirectUpload(file, url, this)

    this.currentUpload = upload
    
    upload.create((error, blob) => {
      if (error) {
        this.handleError(error)
      } else {
        this.handleSuccess(blob)
      }
    })
  }

  directUploadWillStoreFileWithXHR(xhr) {
    this.bindProgressEvents(xhr)
    this.currentXHR = xhr
  }

  bindProgressEvents(xhr) {
    xhr.upload.addEventListener("progress", event => {
      this.updateProgress(event)
    })
  }

  updateProgress(event) {
    if (event.lengthComputable) {
      const progress = Math.round((event.loaded / event.total) * 100)
      this.progressBar.style.width = `${progress}%`
      this.progressBar.setAttribute("aria-valuenow", progress)
      
      // Update status text
      if (this.hasStatusTextTarget) {
        this.statusTextTarget.textContent = `Uploading: ${progress}%`
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
    // Create hidden input with blob id
    const hiddenField = document.createElement('input')
    hiddenField.setAttribute("type", "hidden")
    hiddenField.setAttribute("value", blob.signed_id)
    hiddenField.name = this.inputTarget.name
    this.element.appendChild(hiddenField)

    // Update status text
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = `Upload complete - File ready for submission`
    }

    this.enableSubmit()
    this.hideProgress()
    this.hideCancel()
  }

  handleError(error) {
    // Show error message
    const flash = document.createElement("div")
    flash.className = "mb-4 p-4 border rounded border-red-500 bg-red-50 text-red-700"
    flash.textContent = "Error uploading file. Please try again."
    this.element.insertBefore(flash, this.element.firstChild)

    // Update status text
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "Upload failed - Please try again"
    }

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
    
    // Update status text
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "Upload canceled"
    }
    
    this.enableSubmit()
    this.hideProgress()
    this.hideCancel()
    this.inputTarget.value = ""
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
    this.submitTarget.disabled = false
  }

  disableSubmit() {
    this.submitTarget.disabled = true
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
