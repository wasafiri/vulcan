import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "householdSize", 
    "annualIncome", 
    "submitButton", 
    "rejectionModal",
    "incomeProofRejectionReason",
    "incomeProofRejectionNotes",
    "residencyProofRejectionReason",
    "residencyProofRejectionNotes"
  ]
  
  connect() {
    this.setupProofActionListeners('income');
    this.setupProofActionListeners('residency');
    
    // Initialize FPL thresholds - these will be populated from the server
    this.fplThresholds = {};
    this.fplModifier = 400; // Default to 400% if not set
    
    // Fetch FPL thresholds from the server
    this.fetchFplThresholds();
    
    // Set up predefined rejection reasons
    this.predefinedReasons = {
      income: {
        address_mismatch: "The address provided on your income documentation does not match the application address. Please submit documentation that contains the address exactly matching the one shared in your application.",
        expired: "The income documentation you provided is more than 1 year old or is expired. Please submit documentation that is less than 1 year old and which is not expired.",
        exceeds_threshold: "Based on the income documentation you provided, your household income exceeds the maximum threshold to qualify for the MAT program. The program is designed to assist those with financial need, and unfortunately, your income level is above our current eligibility limits.",
        outdated_ss_award: "Your Social Security benefit award letter is out-of-date. Please submit your most recent award letter, which should be dated within the last 12 months. You can obtain a new benefit verification letter by visiting the Social Security Administration website or contacting your local SSA office.",
        missing_name: "The income documentation you provided does not show your name. Please submit documentation that clearly displays your full name as it appears on your application.",
        wrong_document: "The document you submitted is not an acceptable type of income proof. Please submit one of the following: recent pay stubs, tax returns, Social Security benefit statements, or other official documentation that verifies your income.",
        missing_amount: "The income documentation you provided does not clearly show your income amount. Please submit documentation that clearly displays your income figures, such as pay stubs with earnings clearly visible or benefit statements showing payment amounts."
      },
      residency: {
        address_mismatch: "The address provided on your residency documentation does not match the application address. Please submit documentation that contains the address exactly matching the one shared in your application.",
        expired: "The residency documentation you provided is more than 1 year old or is expired. Please submit documentation that is less than 1 year old and which is not expired.",
        missing_name: "The residency documentation you provided does not show your name. Please submit documentation that clearly displays your full name as it appears on your application.",
        wrong_document: "The document you submitted is not an acceptable type of residency proof. Please submit one of the following: utility bill, lease agreement, mortgage statement, or other official documentation that verifies your Maryland residence."
      }
    };
  }
  
  setupProofActionListeners(proofType) {
    const acceptRadio = document.getElementById(`accept_${proofType}_proof`);
    const rejectRadio = document.getElementById(`reject_${proofType}_proof`);
    const uploadDiv = document.getElementById(`${proofType}_proof_upload`);
    const rejectionDiv = document.getElementById(`${proofType}_proof_rejection`);
    
    if (acceptRadio && rejectRadio && uploadDiv && rejectionDiv) {
      acceptRadio.addEventListener('change', () => {
        uploadDiv.classList.remove('hidden');
        rejectionDiv.classList.add('hidden');
      });
      
      rejectRadio.addEventListener('change', () => {
        uploadDiv.classList.add('hidden');
        rejectionDiv.classList.remove('hidden');
      });
    }
    
    // Set up rejection reason dropdown change handler
    const reasonSelect = document.querySelector(`select[name="${proofType}_proof_rejection_reason"]`);
    const notesTextarea = document.querySelector(`textarea[name="${proofType}_proof_rejection_notes"]`);
    
    if (reasonSelect && notesTextarea) {
      reasonSelect.addEventListener('change', (event) => {
        const selectedReason = event.target.value;
        
        if (selectedReason && selectedReason !== 'other') {
          // Fill in the predefined text
          notesTextarea.value = this.predefinedReasons[proofType][selectedReason];
          
          // Show the full text
          const reasonPreview = document.getElementById(`${proofType}_proof_reason_preview`);
          if (reasonPreview) {
            reasonPreview.textContent = this.predefinedReasons[proofType][selectedReason];
            reasonPreview.classList.remove('hidden');
          }
        } else {
          // Clear the textarea for custom input if "Other" is selected
          notesTextarea.value = '';
          
          // Hide the preview
          const reasonPreview = document.getElementById(`${proofType}_proof_reason_preview`);
          if (reasonPreview) {
            reasonPreview.classList.add('hidden');
          }
        }
      });
    }
  }
  
  fetchFplThresholds() {
    // Fetch FPL thresholds from the server
    fetch('/admin/paper_applications/fpl_thresholds')
      .then(response => response.json())
      .then(data => {
        this.fplThresholds = data.thresholds;
        this.fplModifier = data.modifier;
      })
      .catch(error => {
        console.error('Error fetching FPL thresholds:', error);
      });
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
    const badgeElement = document.getElementById('income-threshold-badge');
    const rejectionButton = document.getElementById('rejection-button');
    
    if (annualIncome > threshold) {
      // Income exceeds threshold - show warning, badge, and disable submit button
      warningElement.classList.remove('hidden');
      badgeElement.classList.remove('hidden');
      this.submitButtonTarget.disabled = true;
      this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed');
      rejectionButton.classList.remove('hidden');
      
      // Update hidden fields in the rejection form
      this.updateRejectionFormFields();
    } else {
      // Income is within threshold - hide warning, badge, and enable submit button
      warningElement.classList.add('hidden');
      badgeElement.classList.add('hidden');
      this.submitButtonTarget.disabled = false;
      this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed');
      rejectionButton.classList.add('hidden');
    }
  }
  
  updateRejectionFormFields() {
    // Copy values from the main form to the rejection form
    document.querySelector('input[name="first_name"]').value = document.querySelector('input[name="constituent[first_name]"]').value;
    document.querySelector('input[name="last_name"]').value = document.querySelector('input[name="constituent[last_name]"]').value;
    document.querySelector('input[name="email"]').value = document.querySelector('input[name="constituent[email]"]').value;
    document.querySelector('input[name="phone"]').value = document.querySelector('input[name="constituent[phone]"]').value;
    document.querySelector('input[name="household_size"]').value = this.householdSizeTarget.value;
    document.querySelector('input[name="annual_income"]').value = this.annualIncomeTarget.value;
  }
  
  openRejectionModal() {
    this.updateRejectionFormFields();
    this.rejectionModalTarget.classList.remove('hidden');
  }
  
  closeRejectionModal() {
    this.rejectionModalTarget.classList.add('hidden');
  }
}
