import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener('input', this.formatDate.bind(this))
    }
  }

  disconnect() {
    if (this.hasInputTarget) {
      this.inputTarget.removeEventListener('input', this.formatDate.bind(this))
    }
  }

  formatDate(event) {
    let input = event.target
    let value = input.value.replace(/\D/g, '')
    
    if (value.length > 8) {
      value = value.substr(0, 8)
    }
    
    if (value.length >= 4) {
      value = value.substr(0, 2) + '/' + value.substr(2, 2) + '/' + value.substr(4)
    } else if (value.length >= 2) {
      value = value.substr(0, 2) + '/' + value.substr(2)
    }
    
    input.value = value
  }
}
