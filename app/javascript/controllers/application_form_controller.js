import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "householdSize", 
    "annualIncome", 
    "submitButton"
  ]
  
  connect() {
    // Initialize FPL thresholds - these will be populated from the server
    this.fplThresholds = {};
    this.fplModifier = 400; // Default to 400% if not set
    
    // Fetch FPL thresholds from the server
    this.fetchFplThresholds();
    
    // Add warning element to the form
    this.addIncomeThresholdWarning();
  }
  
  fetchFplThresholds() {
    // Fetch FPL thresholds from the server
    fetch('/constituent_portal/applications/fpl_thresholds')
      .then(response => response.json())
      .then(data => {
        this.fplThresholds = data.thresholds;
        this.fplModifier = data.modifier;
      })
      .catch(error => {
        console.error('Error fetching FPL thresholds:', error);
      });
  }
  
  addIncomeThresholdWarning() {
    // Create warning element
    const warningElement = document.createElement('div');
    warningElement.id = 'income-threshold-warning';
    warningElement.className = 'hidden bg-red-100 border border-red-400 text-red-700 p-4 rounded mb-4';
    warningElement.setAttribute('role', 'alert');
    
    // Add warning content
    warningElement.innerHTML = `
      <h3 class="font-medium">Income Exceeds Threshold</h3>
      <p>Your annual income exceeds the maximum threshold for your household size.</p>
      <p>Applications with income above the threshold are not eligible for this program.</p>
    `;
    
    // Insert warning at the top of the form, similar to flash messages
    const formContainer = document.querySelector('.form-container');
    const formElement = document.querySelector('form');
    
    // Insert before the form, after the heading
    if (formContainer && formElement) {
      const heading = formContainer.querySelector('h1');
      if (heading) {
        // Insert after the heading and main-content div
        const mainContent = document.getElementById('main-content');
        if (mainContent) {
          mainContent.parentNode.insertBefore(warningElement, mainContent.nextSibling);
        } else {
          // Fallback: insert after heading
          heading.parentNode.insertBefore(warningElement, heading.nextSibling);
        }
      } else {
        // Fallback: insert at the beginning of the form
        formElement.insertBefore(warningElement, formElement.firstChild);
      }
    } else {
      // Fallback: insert at the beginning of the body
      document.body.insertBefore(warningElement, document.body.firstChild);
    }
  }
  
  validateIncomeThreshold() {
    const householdSize = parseInt(this.householdSizeTarget.value) || 0;
    const annualIncome = parseFloat(this.annualIncomeTarget.value) || 0;
    
    if (householdSize < 1 || annualIncome < 1) {
      return; // Not enough data to validate
    }
    
    // Get the base FPL amount for the household size (default to 8-person if larger)
    const baseFpl = this.fplThresholds[Math.min(householdSize, 8)] || 0;
    
    // Calculate the threshold (base FPL * modifier percentage)
    const threshold = baseFpl * (this.fplModifier / 100);
    
    const warningElement = document.getElementById('income-threshold-warning');
    const submitButton = document.querySelector('input[name="submit_application"]');
    
    if (annualIncome > threshold) {
      // Income exceeds threshold - show warning and disable submit button
      warningElement.classList.remove('hidden');
      submitButton.disabled = true;
      submitButton.classList.add('opacity-50', 'cursor-not-allowed');
    } else {
      // Income is within threshold - hide warning and enable submit button
      warningElement.classList.add('hidden');
      submitButton.disabled = false;
      submitButton.classList.remove('opacity-50', 'cursor-not-allowed');
    }
  }
}
