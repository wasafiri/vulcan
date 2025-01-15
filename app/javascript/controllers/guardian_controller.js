// app/javascript/controllers/guardian_controller.js
import { Controller } from "stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("submit", this.validate.bind(this))
  }

  validate(event) {
    const disabilities = this.element.querySelectorAll("input[name$='_disability']:checked")
    if (disabilities.length === 0) {
      alert("Please select at least one disability.")
      event.preventDefault()
    }
  }
}
