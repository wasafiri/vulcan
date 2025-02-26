import { Application } from "@hotwired/stimulus"
import RejectionFormController from "controllers/rejection_form_controller"

describe("RejectionFormController", () => {
  let application
  let element
  let incomeOnlyReasons
  let proofTypeInput

  beforeEach(() => {
    // Set up DOM
    document.body.innerHTML = `
      <div data-controller="rejection-form">
        <input type="hidden" id="rejection-proof-type" value="" data-rejection-form-target="proofType">
        <textarea data-rejection-form-target="reasonField"></textarea>
        <div class="income-only-reasons hidden">
          <button data-reason-type="missingAmount">Missing Amount</button>
          <button data-reason-type="exceedsThreshold">Income Exceeds Threshold</button>
          <button data-reason-type="outdatedSsAward">Outdated SS Award Letter</button>
        </div>
        <button data-proof-type="income">Income Proof</button>
        <button data-proof-type="residency">Residency Proof</button>
      </div>
    `

    // Set up Stimulus controller
    application = Application.start()
    application.register("rejection-form", RejectionFormController)

    element = document.querySelector("[data-controller='rejection-form']")
    incomeOnlyReasons = document.querySelector(".income-only-reasons")
    proofTypeInput = document.querySelector("[data-rejection-form-target='proofType']")
  })

  test("shows income-only reasons when income proof type is selected", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    
    // Simulate clicking on the income proof button
    const incomeButton = document.querySelector("[data-proof-type='income']")
    incomeButton.click()
    
    // Check that the proof type was set correctly
    expect(proofTypeInput.value).toBe("income")
    
    // Check that the income-only reasons are shown
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(false)
  })

  test("hides income-only reasons when residency proof type is selected", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    
    // Simulate clicking on the residency proof button
    const residencyButton = document.querySelector("[data-proof-type='residency']")
    residencyButton.click()
    
    // Check that the proof type was set correctly
    expect(proofTypeInput.value).toBe("residency")
    
    // Check that the income-only reasons are hidden
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(true)
  })

  test("initializes with income-only reasons hidden by default", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    
    // Check that the income-only reasons are hidden by default
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(true)
  })

  test("updates income-only reasons visibility when proof type changes", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    
    // Set the proof type to income
    proofTypeInput.value = "income"
    controller.updateIncomeOnlyReasonsVisibility()
    
    // Check that the income-only reasons are shown
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(false)
    
    // Set the proof type to residency
    proofTypeInput.value = "residency"
    controller.updateIncomeOnlyReasonsVisibility()
    
    // Check that the income-only reasons are hidden
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(true)
  })

  test("selects predefined reason text when button is clicked", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    
    // Set up the controller with values for predefined reasons
    controller.addressMismatchIncomeValue = "Address mismatch income text"
    controller.addressMismatchResidencyValue = "Address mismatch residency text"
    
    // Set the proof type to income
    proofTypeInput.value = "income"
    
    // Create a button with a predefined reason type
    const reasonButton = document.createElement("button")
    reasonButton.dataset.reasonType = "addressMismatch"
    
    // Simulate clicking on the reason button
    controller.selectPredefinedReason({ currentTarget: reasonButton })
    
    // Check that the reason field was populated with the correct text
    const reasonField = document.querySelector("[data-rejection-form-target='reasonField']")
    expect(reasonField.value).toBe("Address mismatch income text")
    
    // Set the proof type to residency
    proofTypeInput.value = "residency"
    
    // Simulate clicking on the reason button again
    controller.selectPredefinedReason({ currentTarget: reasonButton })
    
    // Check that the reason field was populated with the correct text for residency
    expect(reasonField.value).toBe("Address mismatch residency text")
  })

  test("validates form submission", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    
    // Set up a mock event
    const mockEvent = {
      preventDefault: jest.fn()
    }
    
    // Test with empty reason field
    const reasonField = document.querySelector("[data-rejection-form-target='reasonField']")
    reasonField.value = ""
    proofTypeInput.value = "income"
    
    // Validate the form
    controller.validateForm(mockEvent)
    
    // Check that the form submission was prevented
    expect(mockEvent.preventDefault).toHaveBeenCalled()
    
    // Check that the reason field has the error class
    expect(reasonField.classList.contains("border-red-500")).toBe(true)
    
    // Reset the mock
    mockEvent.preventDefault.mockClear()
    
    // Test with filled reason field
    reasonField.value = "Valid reason"
    
    // Validate the form
    controller.validateForm(mockEvent)
    
    // Check that the form submission was not prevented
    expect(mockEvent.preventDefault).not.toHaveBeenCalled()
    
    // Check that the reason field does not have the error class
    expect(reasonField.classList.contains("border-red-500")).toBe(false)
  })
})
