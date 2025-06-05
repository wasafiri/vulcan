import { Controller } from "@hotwired/stimulus"
import { applyTargetSafety } from "../../mixins/target_safety"

class DateInputController extends Controller {
  static targets = ["input", "hidden"]

  connect() {
    // Store bound method references for proper cleanup
    this._boundHandleInput = this.handleInput.bind(this)
    this._boundHandleBlur = this.handleBlur.bind(this)

    // Use target safety for event listener setup
    this.withTarget('input', (input) => {
      input.addEventListener('input', this._boundHandleInput)
      input.addEventListener('blur', this._boundHandleBlur)
    });
  }

  disconnect() {
    // Clean up event listeners using target safety
    this.withTarget('input', (input) => {
      input.removeEventListener('input', this._boundHandleInput)
      input.removeEventListener('blur', this._boundHandleBlur)
    });
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
      this.withTarget('hidden', (hidden) => {
        hidden.value = ""
      });
      return;
    }

    // pull out the pieces using named capture groups
    const match = raw.match(/^(?<m>\d{2})(?<d>\d{2})(?<y>\d{4})$/);
    if (!match || !match.groups) {
      console.error("[DateInput] Regex match failed unexpectedly.");
      this.withTarget('hidden', (hidden) => {
        hidden.value = ""
      });
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
      if (process.env.NODE_ENV !== 'production') {
        console.log("[DateInput] invalid calendar date—skipping");
      }
      // Clear hidden field if date is invalid
      this.withTarget('hidden', (hidden) => {
        hidden.value = ""
      });
      return;
    }

    // format back out for the user (MM/DD/YYYY)
    const pretty = `${m}/${d}/${y}`; // Already have padded strings from regex match
    input.value = pretty;

    // finally, update your hidden field
    this.withTarget('hidden', (hidden) => {
      const iso = `${y}-${m}-${d}`; // Already have padded strings from regex match
      hidden.value = iso;
    });
  }
}

// Apply target safety mixin
applyTargetSafety(DateInputController)

export default DateInputController
