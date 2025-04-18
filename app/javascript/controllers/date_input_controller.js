import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden"]

  // Store bound functions
  boundHandleInput = this.handleInput.bind(this)
  boundHandleBlur = this.handleBlur.bind(this)

  connect() {
    if (this.hasInputTarget) {
      this.inputTarget.addEventListener('input', this.boundHandleInput)
      this.inputTarget.addEventListener('blur', this.boundHandleBlur)
    }
  }

  disconnect() {
    if (this.hasInputTarget) {
      // Use the stored bound references for removal
      this.inputTarget.removeEventListener('input', this.boundHandleInput)
      this.inputTarget.removeEventListener('blur', this.boundHandleBlur)
    }
  }

  handleInput(event) {
    const input = event.target
    let value = input.value.replace(/\D/g, '')
    
    // Auto-format as user types
    if (value.length > 2) value = value.slice(0, 2) + '/' + value.slice(2)
    if (value.length > 5) value = value.slice(0, 5) + '/' + value.slice(5, 9)
    
    input.value = value
  }

  handleBlur(event) {
    const input = event.target;
    let raw = input.value.replace(/\D/g, "");       // strip non‑digits

    // must be exactly MMDDYYYY
    if (!/^(?<m>\d{2})(?<d>\d{2})(?<y>\d{4})$/.test(raw)) {
      // Clear hidden field if input is invalid/incomplete
      if (this.hasHiddenTarget) {
        this.hiddenTarget.value = ""
      }
      return;
    }

    // pull out the pieces using named capture groups
    const match = raw.match(/^(?<m>\d{2})(?<d>\d{2})(?<y>\d{4})$/);
    if (!match || !match.groups) {
      console.error("[DateInput] Regex match failed unexpectedly.");
       if (this.hasHiddenTarget) {
        this.hiddenTarget.value = ""
      }
      return;
    }
    const { m, d, y } = match.groups;

    // sanity‑check date object
    const date = new Date(+y, +m - 1, +d); // Use unary plus (+) to convert strings to numbers
    if (
      date.getFullYear()  != +y ||
      date.getMonth()      != +m - 1 ||
      date.getDate()       != +d
    ) {
      console.log("[DateInput] invalid calendar date—skipping");
      // Clear hidden field if date is invalid
      if (this.hasHiddenTarget) {
        this.hiddenTarget.value = ""
      }
      return;
    }

    // format back out for the user (MM/DD/YYYY)
    const pretty = `${m}/${d}/${y}`; // Already have padded strings from regex match
    input.value = pretty;

    // finally, update your hidden field
    if (this.hasHiddenTarget) {
      const iso = `${y}-${m}-${d}`; // Already have padded strings from regex match
      this.hiddenTarget.value = iso;
    }
  }
}
