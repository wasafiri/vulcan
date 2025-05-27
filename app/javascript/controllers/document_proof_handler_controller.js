import { Controller } from "@hotwired/stimulus"
import { setVisible } from "../utils/visibility"

/**
 * Controller for handling document proof acceptance/rejection
 * 
 * Manages the UI for accepting or rejecting proof documents,
 * toggling file upload sections, and handling rejection reasons.
 */
export default class extends Controller {
  static targets = [
    "acceptRadio",
    "rejectRadio",
    "uploadSection",
    "rejectionSection",
    "fileInput", // Added based on usage
    "rejectionReasonSelect", // Aligned with HTML target name
    "rejectionNotes" // Aligned with HTML target name
  ]

  static values = {
    proofType: String // "income_proof" or "residency_proof"
  }

  connect() {
    // Set initial state based on selected radio button
    this.updateVisibility();
  }

  /**
   * Toggle between accept/reject states
   * @param {Event} event The change event from radio buttons
   */
  toggleProofAction(event) { // Renamed from toggle
    // Update UI based on selection
    this.updateVisibility();
  }

  /**
   * Update the visibility of upload or rejection sections
   * based on the selected radio
   */
  updateVisibility() {
    const isAccepted = this.acceptRadioTarget.checked;
    
    // Toggle visibility of sections using utility
    setVisible(this.uploadSectionTarget, isAccepted);
    setVisible(this.rejectionSectionTarget, !isAccepted);
    
    // Toggle file input enabled state
    if (this.hasFileInputTarget) { // Check if target exists
      this.fileInputTarget.disabled = !isAccepted;

      // Clear file when switching to reject
      if (!isAccepted && this.fileInputTarget.value) {
        this.fileInputTarget.value = '';
      }
    }

    // Toggle required attributes on fields
    if (this.hasRejectionReasonSelectTarget) {
      if (isAccepted) {
        this.rejectionReasonSelectTarget.removeAttribute('required');
      } else {
        this.rejectionReasonSelectTarget.setAttribute('required', 'required');
      }
    }
    if (this.hasRejectionNotesTarget && isAccepted) { // Assuming notes are not required when accepting
        this.rejectionNotesTarget.removeAttribute('required');
    }
    // If rejectionNotes should be required when rejecting, add:
    // else if (this.hasRejectionNotesTarget) { this.rejectionNotesTarget.setAttribute('required', 'required'); }
  }

  /**
   * Preview the rejection reason text
   */
  previewRejectionReason() {
    const reasonPreviewEl = document.getElementById(`${this.proofTypeValue}_reason_preview`);
    if (!reasonPreviewEl) return;

    const selectedReason = this.rejectionReasonSelectTarget.value; // Use aligned target name

    if (selectedReason) {
      // In a real app, we'd use I18n or data attributes to get formatted reason text
      reasonPreviewEl.textContent = this.formatRejectionReason(selectedReason);
      setVisible(reasonPreviewEl, true);
    } else {
      setVisible(reasonPreviewEl, false);
    }
  }
  
  /**
   * Format a rejection reason code into human-readable text
   * @param {string} reasonCode The rejection reason code
   * @returns {string} Formatted reason text
   */
  formatRejectionReason(reasonCode) {
    // This would typically come from Rails I18n
    const reasonMessages = {
      'address_mismatch': 'The address on the document does not match the application address.',
      'expired': 'The document has expired or is not within the required date range.',
      'missing_name': 'The document does not clearly show the applicant\'s name.',
      'wrong_document': 'This is not an acceptable document type for this proof.',
      'missing_amount': 'The income amount is not clearly visible on the document.',
      'exceeds_threshold': 'The income shown exceeds the program\'s threshold.',
      'outdated_ss_award': 'The Social Security award letter is from a previous year.',
      'other': 'There is an issue with this document. Please see notes for details.'
    };
    
    return reasonMessages[reasonCode] || 'This document was rejected. Please provide a valid document.';
  }
}
