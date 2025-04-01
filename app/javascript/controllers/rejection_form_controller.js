import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "proofType",      // Hidden input for proof type 
    "reasonField",    // Text area for rejection reason
    "notesField"      // Optional text area for additional notes
  ]

  static values = {
    // Income & Residency proof rejection reasons
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
    outdatedSsAwardIncome: String,
    
    // Medical certification rejection reasons
    missingProviderCredentials: String,
    incompleteDisabilityDocumentation: String,
    outdatedCertification: String,
    missingSignature: String,
    missingFunctionalLimitations: String,
    incorrectFormUsed: String
  }

  connect() {
    // Clear form on connect
    if (this.hasReasonFieldTarget) {
      this.reasonFieldTarget.value = ""
      this.reasonFieldTarget.classList.remove('border-red-500')
    }
    
    if (this.hasNotesFieldTarget) {
      this.notesFieldTarget.value = ""
    }

    // Listen for proof type changes
    document.addEventListener('click', (event) => {
      if (event.target.matches('[data-proof-type]')) {
        const proofType = event.target.dataset.proofType
        this.proofTypeTarget.value = proofType
        
        // Show/hide specific reason groups based on proof type
        this.updateReasonGroupsVisibility(proofType)
      }
    })
    
    // Initialize visibility based on initial proof type
    this.updateReasonGroupsVisibility(this.proofTypeTarget.value)
  }
  
  updateReasonGroupsVisibility(proofType) {
    // Handle income-only reasons
    const incomeOnlyReasons = document.querySelector('.income-only-reasons')
    if (incomeOnlyReasons) {
      if (proofType === 'income') {
        incomeOnlyReasons.classList.remove('hidden')
      } else {
        incomeOnlyReasons.classList.add('hidden')
      }
    }
    
    // Handle medical-only reasons
    const medicalOnlyReasons = document.querySelector('.medical-only-reasons')
    if (medicalOnlyReasons) {
      if (proofType === 'medical') {
        medicalOnlyReasons.classList.remove('hidden')
        
        // Hide income/residency groups when showing medical
        if (incomeOnlyReasons) incomeOnlyReasons.classList.add('hidden')
        const generalReasons = document.querySelector('.general-reasons')
        if (generalReasons) generalReasons.classList.add('hidden')
      } else {
        medicalOnlyReasons.classList.add('hidden')
        // Show general reasons for income/residency
        const generalReasons = document.querySelector('.general-reasons')
        if (generalReasons) generalReasons.classList.remove('hidden')
      }
    }
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener('click', this._handleProofType)
  }

  // Handle predefined reason selection
  selectPredefinedReason(event) {
    if (!this.hasReasonFieldTarget) {
      console.warn('Missing reason field target for predefined reason selection')
      return
    }

    const reasonType = event.currentTarget.dataset.reasonType
    if (!reasonType) {
      console.warn('Missing reason type in button data attribute')
      return
    }

    // Get the proof type from the hidden field, defaulting to a sensible value if missing
    let proofType = 'general'
    if (this.hasProofTypeTarget && this.proofTypeTarget.value) {
      proofType = this.proofTypeTarget.value
      console.log(`Using proof type from field: ${proofType}`)
    } else {
      // Try to infer from context - check if this is inside the medical certification modal
      const isMedicalModal = event.currentTarget.closest('#medicalCertificationRejectionModal')
      if (isMedicalModal) {
        proofType = 'medical'
        console.log('Inferred medical proof type from modal context')
      }
    }

    let reasonText = null

    // For medical certification reasons
    if (proofType === 'medical') {
      reasonText = this[`${reasonType}Value`]
      console.log(`Looking for medical reason: ${reasonType}Value = ${reasonText ? 'Found' : 'Not found'}`)
    } else {
      // For income/residency, use the composite key approach
      const key = `${reasonType}${proofType.charAt(0).toUpperCase() + proofType.slice(1)}`
      reasonText = this[`${key}Value`]
      console.log(`Looking for ${proofType} reason: ${key}Value = ${reasonText ? 'Found' : 'Not found'}`)
    }
    
    // Directly search for the value as a fallback
    if (!reasonText) {
      // Try direct access to the attribute
      const dataAttributeName = `data-rejection-form-${reasonType}-value`
      const directValue = this.element.getAttribute(dataAttributeName)
      if (directValue) {
        reasonText = directValue
        console.log(`Found reason text via direct attribute: ${dataAttributeName}`)
      }
    }
    
    if (reasonText) {
      this.reasonFieldTarget.value = reasonText
      this.reasonFieldTarget.classList.remove('border-red-500')
    } else {
      console.warn(`No predefined reason found for type: ${reasonType}, proof type: ${proofType}`)
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
