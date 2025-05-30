import { Controller } from "@hotwired/stimulus";
import { setVisible } from "../utils/visibility";
import { createVeryShortDebounce } from "../utils/debounce";

export default class extends Controller {
  static targets = ["radio", "adultSection", "radioSection", "guardianSection", "sectionsForDependentWithGuardian", "commonSections", "dependentField"];
  static outlets = ["guardian-picker"];

  connect() {
    // Guard against multiple connections
    if (this._connected) return;
    this._connected = true;
    
    this._lastState = null; // Track last state to prevent unnecessary dispatches
    this.debouncedRefresh = createVeryShortDebounce(() => this.executeRefresh());
    this.refresh();
    // If the guardian picker outlet is available, observe it for changes.
    // This is an alternative to custom events if direct observation is preferred for future Stimulus versions.
    // For now, relying on guardianPickerOutlet.selectedValue in refresh() called by other actions.
  }

  disconnect() {
    this._connected = false;
    this.debouncedRefresh?.cancel();
    this._lastState = null;
  }

  // This can be called by an action on the guardian-picker if its selection changes,
  // or if this controller needs to react to external changes.
  guardianPickerOutletConnected(outlet, element) {
    console.log("ApplicantTypeController: Guardian Picker Outlet Connected");
    // Use a delayed refresh to avoid immediate recursion
    setTimeout(() => this.refresh(), 50);
  }

  guardianPickerOutletDisconnected(outlet, element) {
    console.log("ApplicantTypeController: Guardian Picker Outlet Disconnected");
    // Use a delayed refresh to avoid immediate recursion
    setTimeout(() => this.refresh(), 50);
  }

  updateApplicantTypeDisplay() { // Called by radio button change
    console.log("ApplicantTypeController: updateApplicantTypeDisplay fired, isDependentSelected:", this.isDependentRadioChecked());
    this.refresh(); // refresh will now handle the event dispatch
  }

  refresh() {
    this.debouncedRefresh();
  }

  executeRefresh() {
    try {
      console.log("ApplicantTypeController: Refresh executing");
      // Check if guardianPickerOutlet is connected and has a value
      const guardianChosen = this.hasGuardianPickerOutlet && this.guardianPickerOutlet.selectedValue;

      // Determine if the dependent section should be shown
      // It's shown if a guardian is chosen OR if the 'dependent' radio is manually checked (and no guardian is chosen)
      const dependentRadioSelected = this.isDependentRadioChecked();

      // Hide the applicant-type radio section when a guardian is chosen
      if (this.hasRadioSectionTarget) {
        setVisible(this.radioSectionTarget, !guardianChosen);
      }

      // Show guardian section (guardian picker) if dependent radio is selected
      if (this.hasGuardianSectionTarget) {
        console.log(`ApplicantTypeController: Refresh - Guardian Section. Dependent Radio Selected: ${dependentRadioSelected}`);
        setVisible(this.guardianSectionTarget, dependentRadioSelected);
        console.log(`ApplicantTypeController: Refresh - Guardian Section updated. New state: ${this.guardianSectionTarget.classList.contains("hidden") ? "hidden" : "visible"}`);
      } else {
        console.log("ApplicantTypeController: Refresh - Guardian Section. No GuardianSectionTarget found.");
      }

      // Show sections for dependent with guardian only if dependent radio is selected AND a guardian is chosen
      const showDependentSections = dependentRadioSelected && guardianChosen;
      if (this.hasSectionsForDependentWithGuardianTarget) {
        setVisible(this.sectionsForDependentWithGuardianTarget, showDependentSections);
      }

      // Manage 'required' attribute for dependent fields
      if (this.hasDependentFieldTargets) {
        this.dependentFieldTargets.forEach(field => {
          setVisible(field, true, { required: showDependentSections });
        });
      }

      // Adult section is hidden if dependent flow is active (either dependent radio selected or guardian chosen)
      const showAdultSection = !dependentRadioSelected && !guardianChosen;
      if (this.hasAdultSectionTarget) {
        setVisible(this.adultSectionTarget, showAdultSection);
      }

      // Disable radio buttons if a guardian is chosen and add title
      const radioTitle = guardianChosen ? "Guardian selected – switch enabled after clearing selection" : "";
      this.radioTargets.forEach(radio => {
        if (radio.disabled !== guardianChosen) {
          radio.disabled = guardianChosen;
        }
        if (radio.title !== radioTitle) {
          radio.title = radioTitle;
        }
      });

      // If a guardian is chosen, ensure the 'dependent' radio is selected
      if (guardianChosen) {
        this.selectRadio("dependent");
        // Ensure dependent info section is visible (already handled by toggle above)
        // Ensure guardian picker section is visible (already handled by toggle above, will be hidden by guardian-picker itself if needed)
      }
      // If no guardian is chosen, and dependent was auto-selected, but then user clicks "The Adult"
      // ensure dependent section is hidden. This is handled by showDependentSection logic.

      // SHOW commonSections when adult flow OR dependent-with-guardian flow
      const showCommon = (!dependentRadioSelected && !guardianChosen) || (dependentRadioSelected && guardianChosen);
      if (this.hasCommonSectionsTarget) {
        setVisible(this.commonSectionsTarget, showCommon);
      }

      // Only dispatch event if the meaningful state has changed
      const currentIsDependentSelected = this.isDependentRadioChecked(); // Re-check after potential selectRadio call
      const stateChanged = !this._lastState || 
        this._lastState.isDependentSelected !== currentIsDependentSelected ||
        this._lastState.guardianChosen !== guardianChosen;

      if (stateChanged) {
        console.log("ApplicantTypeController: Dispatching applicantTypeChanged. isDependentSelected:", currentIsDependentSelected);
        this.dispatch("applicantTypeChanged", { detail: { isDependentSelected: currentIsDependentSelected } });
        
        // Update last state
        this._lastState = { isDependentSelected: currentIsDependentSelected, guardianChosen };
      } else {
        console.log("ApplicantTypeController: State unchanged, skipping event dispatch");
      }

    } catch (error) {
      console.error("ApplicantTypeController: Error in refresh:", error);
    }
  }

  isDependentRadioChecked() {
    const selectedRadio = this.radioTargets.find(radio => radio.checked);
    return selectedRadio?.value === "dependent";
  }

  selectRadio(value) {
    const radioToSelect = this.radioTargets.find(radio => radio.value === value);
    if (radioToSelect && !radioToSelect.checked) {
      radioToSelect.checked = true;
    }
  }
}
