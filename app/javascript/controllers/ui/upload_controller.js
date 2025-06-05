import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["input", "progress", "percentage", "cancel", "submit"]
  static outlets = ["flash"] // Declare flash outlet
  static values = { directUploadUrl: String }

  connect() {
    this.cancelToken = null
    this.uploadInProgress = false
  }

  handleFileSelect(event) {
    const file = event.target.files[0]
    if (!file) return

    if (!this.validateFile(file)) {
      return
    }

    // Show the progress bar and cancel button
    this.progressTarget.classList.remove("hidden")
    this.cancelTarget.classList.remove("hidden")
    
    // Disable the submit button during upload
    this.submitTarget.disabled = true

    // Start the direct upload process
    this.uploadInProgress = true
    this.uploadFile(file)
  }

  validateFile(file) {
    const validFileTypes = ['application/pdf', 'image/jpeg', 'image/png', 'image/tiff', 'image/bmp']
    const maxFileSize = 5 * 1024 * 1024 // 5MB in bytes

    if (!validFileTypes.includes(file.type)) {
      const errorMessage = "Invalid file type. Please upload a PDF or an image file (jpg, jpeg, png, tiff, bmp)."
      if (this.hasFlashOutlet) {
        this.flashOutlet.showError(errorMessage)
      } else {
        alert(errorMessage)
      }
      this.inputTarget.value = ""
      return false
    }

    if (file.size > maxFileSize) {
      const errorMessage = "File is too large. Maximum size allowed is 5MB."
      if (this.hasFlashOutlet) {
        this.flashOutlet.showError(errorMessage)
      } else {
        alert(errorMessage)
      }
      this.inputTarget.value = ""
      return false
    }

    return true
  }

  uploadFile(file) {
    const upload = new DirectUpload(file, this.directUploadUrlValue, this)
    
    upload.create((error, blob) => {
      if (error) {
        this.handleUploadError(error)
      } else {
        this.handleUploadSuccess(blob)
      }
    })
  }

  // DirectUpload delegate methods
  directUploadWillStoreFileWithXHR(xhr) {
    this.cancelToken = xhr
    xhr.upload.addEventListener("progress", event => this.updateProgress(event))
  }

  updateProgress(event) {
    if (event.lengthComputable) {
      const percent = Math.round((event.loaded / event.total) * 100)
      this.progressTarget.querySelector("[role=progressbar]").style.width = `${percent}%`
      this.percentageTarget.textContent = `${percent}%`
    }
  }

  cancelUpload() {
    if (this.cancelToken && this.uploadInProgress) {
      this.cancelToken.abort()
      this.resetUpload()
      this.inputTarget.value = ""
    }
  }

  handleUploadError(error) {
    console.error("Upload error:", error)
    const errorMessage = "There was an error uploading your file. Please try again."
    if (this.hasFlashOutlet) {
      this.flashOutlet.showError(errorMessage)
    } else {
      alert(errorMessage)
    }
    this.resetUpload()
  }

  handleUploadSuccess(blob) {
    // Create a hidden field with the signed_id
    const hiddenField = document.createElement('input')
    hiddenField.setAttribute("type", "hidden")
    hiddenField.setAttribute("name", this.inputTarget.name)
    hiddenField.setAttribute("value", blob.signed_id)
    
    // Add it to the form
    this.element.appendChild(hiddenField)
    
    // Update UI
    this.progressTarget.querySelector("[role=progressbar]").style.width = "100%"
    this.percentageTarget.textContent = "100%"
    
    // Enable submit button
    this.submitTarget.disabled = false
    this.uploadInProgress = false
    
    // Show success message
    setTimeout(() => {
      this.progressTarget.classList.add("hidden")
      this.cancelTarget.classList.add("hidden")
    }, 1000)
  }

  resetUpload() {
    // Reset progress bar
    this.progressTarget.querySelector("[role=progressbar]").style.width = "0%"
    this.percentageTarget.textContent = "0%"
    
    // Hide progress bar and cancel button
    this.progressTarget.classList.add("hidden")
    this.cancelTarget.classList.add("hidden")
    
    // Enable submit button
    this.submitTarget.disabled = false
    this.uploadInProgress = false
  }
}
