import { Application } from "@hotwired/stimulus"
import PaperApplicationController from "controllers/paper_application_controller"

describe("PaperApplicationController", () => {
  let application
  let controller
  let element
  let incomeProofInput
  let residencyProofInput
  let incomeProofSignedId
  let residencyProofSignedId
  
  beforeEach(() => {
    // Set up DOM
    document.body.innerHTML = `
      <form data-controller="paper-application">
        <!-- Income proof radio buttons -->
        <input type="radio" id="accept_income_proof" name="income_proof_action" value="accept">
        <input type="radio" id="reject_income_proof" name="income_proof_action" value="reject">
        
        <!-- Residency proof radio buttons -->
        <input type="radio" id="accept_residency_proof" name="residency_proof_action" value="accept">
        <input type="radio" id="reject_residency_proof" name="residency_proof_action" value="reject">
        
        <!-- File inputs -->
        <input type="file" name="income_proof">
        <input type="file" name="residency_proof">
        
        <!-- Hidden signed_id fields -->
        <input type="hidden" name="income_proof_signed_id" value="">
        <input type="hidden" name="residency_proof_signed_id" value="">
        
        <!-- Status text elements -->
        <div id="income_proof_upload">
          <div data-upload-target="statusText">No file selected</div>
        </div>
        <div id="residency_proof_upload">
          <div data-upload-target="statusText">No file selected</div>
        </div>
        
        <!-- Rejection sections -->
        <div id="income_proof_rejection">
          <select name="income_proof_rejection_reason">
            <option value="">Select a reason</option>
            <option value="address_mismatch">Address Mismatch</option>
          </select>
        </div>
        <div id="residency_proof_rejection">
          <select name="residency_proof_rejection_reason">
            <option value="">Select a reason</option>
            <option value="address_mismatch">Address Mismatch</option>
          </select>
        </div>
        
        <!-- Submit button -->
        <button type="submit" data-paper-application-target="submitButton">Submit</button>
      </form>
    `

    // Set up Stimulus controller
    application = Application.start()
    application.register("paper-application", PaperApplicationController)

    element = document.querySelector("[data-controller='paper-application']")
    incomeProofInput = document.querySelector("input[name='income_proof']")
    residencyProofInput = document.querySelector("input[name='residency_proof']")
    incomeProofSignedId = document.querySelector("input[name='income_proof_signed_id']")
    residencyProofSignedId = document.querySelector("input[name='residency_proof_signed_id']")
    
    // Initialize controller
    controller = application.getControllerForElementAndIdentifier(element, "paper-application")
  })

  test("disables file input when reject is selected", () => {
    // Trigger reject radio button for income proof
    const incomeRejectRadio = document.getElementById("reject_income_proof")
    incomeRejectRadio.click()
    
    // Check that the file input is disabled
    expect(incomeProofInput.disabled).toBe(true)
    
    // Trigger reject radio button for residency proof
    const residencyRejectRadio = document.getElementById("reject_residency_proof")
    residencyRejectRadio.click()
    
    // Check that the file input is disabled
    expect(residencyProofInput.disabled).toBe(true)
  })

  test("enables file input when accept is selected", () => {
    // First disable by selecting reject
    document.getElementById("reject_income_proof").click()
    expect(incomeProofInput.disabled).toBe(true)
    
    // Then enable by selecting accept
    document.getElementById("accept_income_proof").click()
    expect(incomeProofInput.disabled).toBe(false)
  })

  test("clears file input and signed_id when switching to reject", () => {
    // Set up file input with a value
    const dataTransfer = new DataTransfer()
    const file = new File(['sample content'], 'sample.pdf', { type: 'application/pdf' })
    dataTransfer.items.add(file)
    incomeProofInput.files = dataTransfer.files
    
    // Set up signed_id with a value
    incomeProofSignedId.value = "test-signed-id-123"
    
    // Initially select accept, then switch to reject
    document.getElementById("accept_income_proof").click()
    document.getElementById("reject_income_proof").click()
    
    // Check that file input is cleared
    expect(incomeProofInput.value).toBe("")
    
    // Check that signed_id is cleared
    expect(incomeProofSignedId.value).toBe("")
  })

  test("validateForm returns false when no option selected", () => {
    // Mock the showError method
    controller.showError = jest.fn()
    
    // No radio buttons selected
    const result = controller.validateForm()
    
    // Validation should fail
    expect(result).toBe(false)
    expect(controller.showError).toHaveBeenCalledWith(expect.stringContaining("Please select an option for income proof"))
  })

  test("validateForm returns false when accept selected but no file uploaded", () => {
    // Mock the showError method
    controller.showError = jest.fn()
    
    // Select accept for income proof but don't upload a file
    document.getElementById("accept_income_proof").click()
    document.getElementById("accept_residency_proof").click()
    
    const result = controller.validateForm()
    
    // Validation should fail
    expect(result).toBe(false)
    expect(controller.showError).toHaveBeenCalledWith(expect.stringContaining("Please upload an income proof document"))
  })

  test("validateForm returns false when reject selected but no reason chosen", () => {
    // Mock the showError method
    controller.showError = jest.fn()
    
    // Select reject for income proof but don't select a reason
    document.getElementById("reject_income_proof").click()
    document.getElementById("reject_residency_proof").click()
    document.querySelector("select[name='residency_proof_rejection_reason']").value = "address_mismatch"
    
    const result = controller.validateForm()
    
    // Validation should fail
    expect(result).toBe(false)
    expect(controller.showError).toHaveBeenCalledWith(expect.stringContaining("Please select a reason for rejecting income proof"))
  })

  test("validateForm returns true when all requirements are met", () => {
    // Mock the showError method
    controller.showError = jest.fn()
    
    // Set up valid state: accept with file for income, reject with reason for residency
    document.getElementById("accept_income_proof").click()
    incomeProofSignedId.value = "test-signed-id-123"
    
    document.getElementById("reject_residency_proof").click()
    document.querySelector("select[name='residency_proof_rejection_reason']").value = "address_mismatch"
    
    const result = controller.validateForm()
    
    // Validation should pass
    expect(result).toBe(true)
    expect(controller.showError).not.toHaveBeenCalled()
  })
})
