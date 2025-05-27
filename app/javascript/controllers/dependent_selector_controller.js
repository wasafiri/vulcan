import { Controller } from "@hotwired/stimulus"
import { setVisible } from "../utils/visibility"

/**
 * Dependent Selector Controller
 * 
 * Manages dependent selection in application forms,
 * including showing/hiding dependent selection UI and updating form titles.
 */
export default class extends Controller {
  static targets = [
    "dependentSection",
    "dependentSelect", 
    "formTitle"
  ]

  static values = {
    userId: String
  }

  connect() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("DependentSelectorController connected");
    }
    
    // Guard against multiple connections
    if (this._initialized) return;
    this._initialized = true;
    
    // Track state - don't rely on DOM classes
    this._isForSelf = true;
    
    // Initialize immediately to avoid Capybara visibility issues
    this.initializeDependentSelection();
  }

  disconnect() {
    this._cleanupListeners();
    this._initialized = false;
  }

  // Toggle dependent selection visibility based on radio button selection
  toggleDependentSelection(event) {
    if (process.env.NODE_ENV !== 'production') {
      console.log("toggleDependentSelection called", event.target.value);
    }
    
    if (!this.hasDependentSectionTarget) {
      if (process.env.NODE_ENV !== 'production') {
        console.log("No dependentSectionTarget found");
      }
      return;
    }

    const isForSelf = event.target.value === "true";
    this._isForSelf = isForSelf;
    
    if (isForSelf) {
      this.hideDependentSection();
      this.updateFormTitle("New Application");
    } else {
      this.showDependentSection();
      this.updateFormTitle("New Application");
      this._ensureListener();
    }
    
    // Dispatch event for other controllers to listen to
    this.dispatch("selectionChanged", {
      detail: { isForSelf, target: event.target }
    });
  }

  // Alias for toggleDependentSelection to match the action name in the view
  toggleAction(event) {
    this.toggleDependentSelection(event);
  }

  // Alias for updateDependentName to match the action name in the view
  selectDependentAction(event) {
    this.updateDependentName(event);
  }

  // Update form title when dependent selection changes
  updateDependentName() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("updateDependentName called");
    }
    
    this.updateFormTitleFromSelection();
    
    // Dispatch event with selected dependent info
    if (this.hasDependentSelectTarget && this.dependentSelectTarget.value) {
      const selectedOption = this.dependentSelectTarget.options[this.dependentSelectTarget.selectedIndex];
      
      this.dispatch("dependentSelected", {
        detail: {
          dependentId: this.dependentSelectTarget.value,
          dependentName: selectedOption.text
        }
      });
    }
  }

  showDependentSection() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("showDependentSection called");
    }
    
    setVisible(this.dependentSectionTarget, true, { required: true });
    
    if (this.hasDependentSelectTarget) {
      this._ensureListener();
    }
  }

  hideDependentSection() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("hideDependentSection called");
    }
    
    setVisible(this.dependentSectionTarget, false);
    
    if (this.hasDependentSelectTarget) {
      this.dependentSelectTarget.removeAttribute("required");
      this.dependentSelectTarget.value = "";
    }
  }

  // Helper to ensure listener is set up correctly without duplicates
  _ensureListener() {
    if (!this.hasDependentSelectTarget) return;
    
    // Create bound method if it doesn't exist
    if (!this._boundUpdateDependentName) {
      this._boundUpdateDependentName = this.updateDependentName.bind(this);
    }
    
    // Remove existing listener (if any) and add new one
    this.dependentSelectTarget.removeEventListener("change", this._boundUpdateDependentName);
    this.dependentSelectTarget.addEventListener("change", this._boundUpdateDependentName);
  }

  // Clean up event listeners
  _cleanupListeners() {
    if (this._boundUpdateDependentName && this.hasDependentSelectTarget) {
      this.dependentSelectTarget.removeEventListener('change', this._boundUpdateDependentName);
    }
  }

  updateFormTitleFromSelection() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("updateFormTitleFromSelection called");
    }
    
    if (!this.hasDependentSelectTarget) {
      if (process.env.NODE_ENV !== 'production') {
        console.log("Missing dependentSelectTarget:", this.hasDependentSelectTarget);
      }
      return;
    }
    
    if (this.dependentSelectTarget.value) {
      const selectedOption = this.dependentSelectTarget.options[this.dependentSelectTarget.selectedIndex]
      const dependentName = selectedOption.text
      if (process.env.NODE_ENV !== 'production') {
        console.log("Updating title to:", `New Application for ${dependentName}`);
      }
      this.updateFormTitle(`New Application for ${dependentName}`)
    } else {
      if (process.env.NODE_ENV !== 'production') {
        console.log("No dependent selected, using base title");
      }
      this.updateFormTitle("New Application")
    }
  }

  updateFormTitle(title) {
    if (process.env.NODE_ENV !== 'production') {
      console.log("updateFormTitle called with:", title);
    }
    
    if (this.hasFormTitleTarget) {
      this.formTitleTarget.textContent = title
      if (process.env.NODE_ENV !== 'production') {
        console.log("Title updated successfully");
      }
    } else {
      if (process.env.NODE_ENV !== 'production') {
        console.log("No formTitleTarget found - falling back to element by ID");
      }
      const titleElement = document.getElementById("form-title");
      if (titleElement) {
        titleElement.textContent = title;
        if (process.env.NODE_ENV !== 'production') {
          console.log("Fallback title updated successfully");
        }
      }
    }
  }

  // Initialize dependent selection based on URL parameters or existing state
  initializeDependentSelection() {
    if (process.env.NODE_ENV !== 'production') {
      console.log("initializeDependentSelection called directly");
    }
    
    const urlParams = new URLSearchParams(window.location.search)
    const forSelfParam = urlParams.get('for_self')
    const userIdParam = urlParams.get('user_id')
    
    // Determine if this should be a dependent application
    const isForDependent = this.shouldInitializeForDependent(forSelfParam, userIdParam)
    
    if (isForDependent) {
      this.initializeDependentApplication(userIdParam)
    } else {
      this.initializeSelfApplication()
    }
    
    // After initialization, ensure listener is set if section is visible
    if (this.hasDependentSelectTarget && !this._isForSelf) {
      this._ensureListener();
    }
  }

  shouldInitializeForDependent(forSelfParam, userIdParam) {
    return forSelfParam === 'false' || 
           userIdParam !== null || 
           (this.hasDependentSectionTarget && !this.dependentSectionTarget.classList.contains('hidden'))
  }

  initializeDependentApplication(userIdParam) {
    // Find and select the "for dependent" radio button
    const applyDependentRadio = document.querySelector('input[value="false"][name="for_self"]') || 
                               document.getElementById('apply_for_dependent')
    if (applyDependentRadio) {
      applyDependentRadio.checked = true
      if (process.env.NODE_ENV !== 'production') {
        console.log("DSC: Selected 'for dependent' radio button")
      }
    } else {
      if (process.env.NODE_ENV !== 'production') {
        console.log("DSC: Could not find 'for dependent' radio button")
      }
    }
    
    this._isForSelf = false;
    this.showDependentSection()
    
    // Set specific dependent if provided in URL
    if (userIdParam && this.hasDependentSelectTarget) {
      this.selectDependentById(userIdParam)
    }
    
    this.updateFormTitleFromSelection()
  }

  initializeSelfApplication() {
    // Find and select the "for self" radio button
    const applySelfRadio = document.querySelector('input[value="true"][name="for_self"]') || 
                          document.getElementById('apply_for_self')
    if (applySelfRadio) {
      applySelfRadio.checked = true
      if (process.env.NODE_ENV !== 'production') {
        console.log("DSC: Selected 'for self' radio button")
      }
    } else {
      if (process.env.NODE_ENV !== 'production') {
        console.log("DSC: Could not find 'for self' radio button")
      }
    }
    
    this._isForSelf = true;
    if (this.hasDependentSectionTarget) {
      this.hideDependentSection()
    }
    
    this.updateFormTitle("New Application")
  }

  selectDependentById(userId) {
    if (!this.hasDependentSelectTarget) return
    
    // Find and select the option with matching user ID
    Array.from(this.dependentSelectTarget.options).forEach(option => {
      if (option.value === userId) {
        this.dependentSelectTarget.value = userId
      }
    })
    
    // Update title after selection
    this.updateFormTitleFromSelection()
  }

  // Public API for other controllers
  getCurrentSelection() {
    return {
      isForSelf: this._isForSelf,
      dependentId: this.hasDependentSelectTarget ? this.dependentSelectTarget.value : null,
      dependentName: this.getSelectedDependentName()
    }
  }

  getSelectedDependentName() {
    if (!this.hasDependentSelectTarget || !this.dependentSelectTarget.value) {
      return null
    }
    
    const selectedOption = this.dependentSelectTarget.options[this.dependentSelectTarget.selectedIndex]
    return selectedOption ? selectedOption.text : null
  }

  setSelection(isForSelf, dependentId = null) {
    if (isForSelf) {
      this.initializeSelfApplication()
    } else {
      this.initializeDependentApplication(dependentId)
    }
  }
}
