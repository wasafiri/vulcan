import { Controller } from "@hotwired/stimulus";
import { setVisible } from "../../utils/visibility";

// Handles guardian‑selection UI toggling and central state.
export default class extends Controller {
  static targets = ["searchPane", "selectedPane", "guardianIdField"];

  connect() {
    this.selectedValue = !!(this.hasGuardianIdFieldTarget && this.guardianIdFieldTarget.value);
    this.togglePanes();
    this._lastDispatchTime = 0;
  }

  /* Public API ----------------------------------------------------------- */
  selectGuardian(id, displayHTML) {
    if (this.hasGuardianIdFieldTarget) this.guardianIdFieldTarget.value = id;
    const box = this.selectedPaneTarget.querySelector(".guardian-details-container");
    if (box) box.innerHTML = displayHTML;
    this.selectedValue = true;
    this.togglePanes();
    this.dispatchSelectionChange();
  }

  clearSelection() {
    if (this.hasGuardianIdFieldTarget) this.guardianIdFieldTarget.value = "";
    this.selectedValue = false;
    this.togglePanes();
    this.dispatchSelectionChange();
  }

  /* Internal helpers ----------------------------------------------------- */
  togglePanes() {
    const hideSearch = this.selectedValue;
    setVisible(this.searchPaneTarget, !hideSearch);
    setVisible(this.selectedPaneTarget, hideSearch);
  }

  dispatchSelectionChange() {
    // Debounce the dispatch to prevent rapid-fire events
    const now = Date.now();
    if (now - this._lastDispatchTime < 100) {
      return; // Skip if called too recently
    }
    this._lastDispatchTime = now;
    
    // Use a small delay to ensure DOM changes are complete
    setTimeout(() => {
      this.dispatch("selectionChange", { detail: { selectedValue: this.selectedValue } });
    }, 10);
  }
}
