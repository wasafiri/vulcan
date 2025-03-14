import { Controller } from "@hotwired/stimulus"

// This controller provides UI feedback for file selection in the paper application form
// It's been simplified to use standard Rails file uploads instead of direct uploads
export default class extends Controller {
  static targets = ["input", "statusText"]

  connect() {
    // Set default status text
    if (this.hasStatusTextTarget) {
      this.statusTextTarget.textContent = "No file selected"
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
  
  // Helper for formatting file sizes
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }
}
