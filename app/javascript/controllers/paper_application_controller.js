import { Controller } from "@hotwired/stimulus"

// Controls the Paper Application form behavior
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
    this.setupRadioListeners()
    this.validateIncomeThreshold()
    this.initializeFormValidation()
    
    // Enable file inputs for the pre-selected "accept" options
    this.enableFileInput('income_proof')
    this.enableFileInput('residency_proof')
    
    // Make sure rejection fields are hidden
    document.getElementById('income_proof_rejection').classList.add('hidden')
    document.getElementById('residency_proof_rejection').classList.add('hidden')
    
    // Add debug info
    console.log('Paper application controller connected')
    console.log('Income proof radio checked:', document.getElementById('accept_income_proof').checked)
    console.log('Residency proof radio checked:', document.getElementById('accept_residency_proof').checked)
  }

  setupRadioListeners() {
    // Income proof radio buttons
    document.getElementById('accept_income_proof').addEventListener('change', () => {
      document.getElementById('income_proof_upload').classList.remove('hidden')
      document.getElementById('income_proof_rejection').classList.add('hidden')
      this.enableFileInput('income_proof')
    })

    document.getElementById('reject_income_proof').addEventListener('change', () => {
      document.getElementById('income_proof_upload').classList.add('hidden')
      document.getElementById('income_proof_rejection').classList.remove('hidden')
      this.clearFileUpload('income_proof')
      this.disableFileInput('income_proof')
    })

    // Residency proof radio buttons
    document.getElementById('accept_residency_proof').addEventListener('change', () => {
      document.getElementById('residency_proof_upload').classList.remove('hidden')
      document.getElementById('residency_proof_rejection').classList.add('hidden')
      this.enableFileInput('residency_proof')
    })

    document.getElementById('reject_residency_proof').addEventListener('change', () => {
      document.getElementById('residency_proof_upload').classList.add('hidden')
      document.getElementById('residency_proof_rejection').classList.remove('hidden')
      this.clearFileUpload('residency_proof')
      this.disableFileInput('residency_proof')
    })
  }

  // Enable file input when Accept is selected
  enableFileInput(inputName) {
    const fileInput = document.querySelector(`input[name="${inputName}"]`)
    if (fileInput) {
      fileInput.disabled = false
    }
  }

  // Disable file input when Reject is selected
  disableFileInput(inputName) {
    const fileInput = document.querySelector(`input[name="${inputName}"]`)
    if (fileInput) {
      fileInput.disabled = true
    }
  }

  // Clear file input when switching to Reject
  clearFileUpload(inputName) {
    // Clear file input
    const fileInput = document.querySelector(`input[name="${inputName}"]`)
    if (fileInput) {
      fileInput.value = ''
    }
  }

  // Set up form validation before submission
  initializeFormValidation() {
    const form = this.element
    form.addEventListener('submit', (event) => {
      if (!this.validateForm()) {
        event.preventDefault()
      }
    })
  }

  // Validate the form before submission
  validateForm() {
    let isValid = true
    
    // Validate income proof
    if (document.getElementById('accept_income_proof').checked) {
      const fileInput = document.querySelector('input[name="income_proof"]')
      if (!fileInput || !fileInput.files || fileInput.files.length === 0) {
        this.showError('Please upload an income proof document')
        isValid = false
      }
    } else if (document.getElementById('reject_income_proof').checked) {
      const reasonSelect = document.querySelector('select[name="income_proof_rejection_reason"]')
      if (!reasonSelect || !reasonSelect.value) {
        this.showError('Please select a reason for rejecting income proof')
        isValid = false
      }
    } else {
      this.showError('Please select an option for income proof')
      isValid = false
    }
    
    // Validate residency proof
    if (document.getElementById('accept_residency_proof').checked) {
      const fileInput = document.querySelector('input[name="residency_proof"]')
      if (!fileInput || !fileInput.files || fileInput.files.length === 0) {
        this.showError('Please upload a residency proof document')
        isValid = false
      }
    } else if (document.getElementById('reject_residency_proof').checked) {
      const reasonSelect = document.querySelector('select[name="residency_proof_rejection_reason"]')
      if (!reasonSelect || !reasonSelect.value) {
        this.showError('Please select a reason for rejecting residency proof')
        isValid = false
      }
    } else {
      this.showError('Please select an option for residency proof')
      isValid = false
    }
    
    return isValid
  }

  // Show an error message at the top of the form
  showError(message) {
    // Check if error container already exists
    let errorContainer = document.querySelector('.form-error-container')
    if (!errorContainer) {
      // Create new error container if not found
      errorContainer = document.createElement('div')
      errorContainer.className = 'form-error-container bg-red-100 border border-red-400 text-red-700 p-4 rounded mb-4'
      this.element.insertBefore(errorContainer, this.element.firstChild)
    }
    
    const errorMessage = document.createElement('p')
    errorMessage.textContent = message
    errorContainer.appendChild(errorMessage)
  }

  async validateIncomeThreshold() {
    if (!this.hasHouseholdSizeTarget || !this.hasAnnualIncomeTarget) return

    const householdSize = parseInt(this.householdSizeTarget.value) || 0
    const annualIncome = parseFloat(this.annualIncomeTarget.value) || 0
    
    if (householdSize <= 0 || annualIncome <= 0) return
    
    try {
      // Fetch FPL thresholds from the server
      const response = await fetch('/admin/paper_applications/fpl_thresholds')
      const data = await response.json()
      
      // Calculate the threshold for the household size
      let size = Math.min(householdSize, 8) // Max 8 person household in our thresholds
      let baseFpl = data.thresholds[size] || data.thresholds[8] // Default to 8 if size not found
      let threshold = baseFpl * (data.modifier / 100.0)
      
      const exceedsThreshold = annualIncome > threshold
      
      // Show warning if income exceeds threshold
      const warningElement = document.getElementById('income-threshold-warning')
      const rejectionButton = document.getElementById('rejection-button')
      
      if (exceedsThreshold) {
        warningElement.classList.remove('hidden')
        rejectionButton.classList.remove('hidden')
        this.submitButtonTarget.disabled = true
      } else {
        warningElement.classList.add('hidden')
        rejectionButton.classList.add('hidden')
        this.submitButtonTarget.disabled = false
      }
      
      // Update badge
      const badgeElement = document.getElementById('income-threshold-badge')
      if (badgeElement) {
        if (exceedsThreshold) {
          badgeElement.classList.remove('hidden')
        } else {
          badgeElement.classList.add('hidden')
        }
      }
    } catch (error) {
      console.error('Error validating income threshold:', error)
    }
  }
  
  openRejectionModal() {
    if (!this.hasRejectionModalTarget) return
    
    // Copy constituent information to the modal form
    const firstNameField = document.querySelector('input[name="constituent[first_name]"]')
    const lastNameField = document.querySelector('input[name="constituent[last_name]"]')
    const emailField = document.querySelector('input[name="constituent[email]"]')
    const phoneField = document.querySelector('input[name="constituent[phone]"]')
    
    document.querySelector('input[name="first_name"]').value = firstNameField?.value || ''
    document.querySelector('input[name="last_name"]').value = lastNameField?.value || ''
    document.querySelector('input[name="email"]').value = emailField?.value || ''
    document.querySelector('input[name="phone"]').value = phoneField?.value || ''
    document.querySelector('input[name="household_size"]').value = this.householdSizeTarget?.value || ''
    document.querySelector('input[name="annual_income"]').value = this.annualIncomeTarget?.value || ''
    
    this.rejectionModalTarget.classList.remove('hidden')
  }
  
  closeRejectionModal() {
    if (!this.hasRejectionModalTarget) return
    this.rejectionModalTarget.classList.add('hidden')
  }
}
