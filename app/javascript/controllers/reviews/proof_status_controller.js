import { Controller } from "@hotwired/stimulus"
import { applyTargetSafety } from "../../mixins/target_safety"
import { setVisible } from "../../utils/visibility"

// Handles showing/hiding proof upload and rejection sections based on status
class ProofStatusController extends Controller {
  static targets = ["uploadSection", "rejectionSection", "radioButtons"]

  connect() {
    // Initialize sections based on current selection with a small delay
    // to ensure the DOM is fully loaded and the radio button state is recognized
    this._initTimer = setTimeout(() => {
      const selectedStatus = this.getSelectedRadio();
      if (selectedStatus) {
        if (process.env.NODE_ENV !== 'production') {
          console.log('Initial status:', selectedStatus.value)
        }
        this.toggle({ target: selectedStatus })
      } else {
        // Fallback: If no radio is checked, default to showing upload section
        if (process.env.NODE_ENV !== 'production') {
          console.log('No radio checked, defaulting to upload section')
        }
        this.withTarget('uploadSection', (target) => setVisible(target, true));
        this.withTarget('rejectionSection', (target) => setVisible(target, false));
      }
    }, 100) // Increased delay to ensure DOM is fully loaded
  }

  disconnect() {
    if (this._initTimer) {
      clearTimeout(this._initTimer);
    }
  }

  // Get the currently selected radio button using targets
  getSelectedRadio() {
    // Use target safety for checking radioButtons target
    return this.withTarget('radioButtons', (target) => {
      // radioButtonsTarget should contain all radio buttons
      const radios = this.radioButtonsTargets || [target];
      return radios.find(radio => radio.checked) || null;
    }, null);
  }

  // Toggle sections based on status
  toggle(event) {
    // Check for both "approved" and "accepted" values to support both proofs and medical certifications
    const isApproved = event.target.value === "approved" || event.target.value === "accepted"
    
    if (process.env.NODE_ENV !== 'production') {
      console.log('Toggle called:', event.target.value, 'isApproved:', isApproved)
    }
    
    // Use setVisible utility for consistent visibility management
    this.withTarget('uploadSection', (target) => setVisible(target, isApproved));
    this.withTarget('rejectionSection', (target) => setVisible(target, !isApproved));
  }
}

// Apply target safety mixin
applyTargetSafety(ProofStatusController)

export default ProofStatusController
