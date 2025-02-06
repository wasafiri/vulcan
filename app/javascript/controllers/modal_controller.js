// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog" ]

  openRejectionForm(event) {
    event.preventDefault()
    this.dialogTarget.classList.remove('hidden')
  }

  close() {
    this.dialogTarget.classList.add('hidden')
  }
}