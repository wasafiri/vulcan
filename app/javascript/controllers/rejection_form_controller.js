import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "proofType",    // Hidden input for proof type
    "reasonField"   // Text area for rejection reason
  ]

  static values = {
    addressMismatchIncome: String,
    addressMismatchResidency: String,
    expiredIncome: String,
    expiredResidency: String,
    missingNameIncome: String,
    missingNameResidency: String,
    wrongDocumentIncome: String,
    wrongDocumentResidency: String,
    missingAmountIncome: String,
    exceedsThresholdIncome: String,
    outdatedSsAwardIncome: String
  }

  connect() {
    // Clear form on connect
    if (this.hasReasonFieldTarget) {
      this.reasonFieldTarget.value = ""
      this.reasonFieldTarget.classList.remove('border-red-500')
    }

    // Listen for proof type changes
    document.addEventListener('click', (event) => {
      if (event.target.matches('[data-proof-type]')) {
        const proofType = event.target.dataset.proofType
        this.proofTypeTarget.value = proofType
        
        // Show/hide income-only reasons based on proof type
        const incomeOnlyReasons = document.querySelector('.income-only-reasons')
        if (incomeOnlyReasons) {
          if (proofType === 'income') {
            incomeOnlyReasons.classList.remove('hidden')
          } else {
            incomeOnlyReasons.classList.add('hidden')
          }
        }
      }
    })
    
    // Initialize income-only reasons visibility based on initial proof type
    this.updateIncomeOnlyReasonsVisibility()
  }
  
  updateIncomeOnlyReasonsVisibility() {
    const proofType = this.proofTypeTarget.value
    const incomeOnlyReasons = document.querySelector('.income-only-reasons')
    if (incomeOnlyReasons) {
      if (proofType === 'income') {
        incomeOnlyReasons.classList.remove('hidden')
      } else {
        incomeOnlyReasons.classList.add('hidden')
      }
    }
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener('click', this._handleProofType)
  }

  // Handle predefined reason selection
  selectPredefinedReason(event) {
    if (!this.hasReasonFieldTarget || !this.hasProofTypeTarget) {
      console.warn('Missing required targets for predefined reason selection')
      return
    }

    const reasonType = event.currentTarget.dataset.reasonType
    const proofType = this.proofTypeTarget.value
    
    if (!reasonType || !proofType) {
      console.warn('Missing reason type or proof type')
      return
    }

    // Get reason text from values
    const key = `${reasonType}${proofType.charAt(0).toUpperCase() + proofType.slice(1)}`
    const reasonText = this[`${key}Value`]
    
    if (reasonText) {
      this.reasonFieldTarget.value = reasonText
      this.reasonFieldTarget.classList.remove('border-red-500')
    } else {
      console.warn(`No predefined reason found for ${key}`)
    }
  }

  // Handle form validation
  validateForm(event) {
    if (!this.hasReasonFieldTarget) {
      console.warn('Missing reason field target')
      return
    }

    if (!this.hasProofTypeTarget || !this.proofTypeTarget.value) {
      console.warn('Missing proof type')
      event.preventDefault()
      return
    }

    const reasonField = this.reasonFieldTarget
    const reasonText = reasonField.value.trim()

    if (!reasonText) {
      event.preventDefault()
      reasonField.classList.add('border-red-500')
      reasonField.focus()
      return
    }

    reasonField.classList.remove('border-red-500')
  }
}
