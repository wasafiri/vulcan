import { Application } from "@hotwired/stimulus"
import RejectionFormController from "controllers/forms/rejection_form_controller"

describe("RejectionFormController", () => {
  let application
  let element
  let incomeOnlyReasons

  beforeEach(() => {
    // Set up DOM
    document.body.innerHTML = `
      <div data-controller="rejection-form">
        <input type="hidden" id="rejection-proof-type" value="" data-rejection-form-target="proofType">
        <textarea data-rejection-form-target="reasonField"></textarea>
        <div class="income-only-reasons hidden" data-rejection-form-target="incomeOnlyReasons">
          <button data-reason-type="missingAmount">Missing Amount</button>
          <button data-reason-type="exceedsThreshold">Income Exceeds Threshold</button>
          <button data-reason-type="outdatedSsAward">Outdated SS Award Letter</button>
        </div>
        <button data-action="click->rejection-form#handleProofTypeClick" data-proof-type="income">Income Proof</button>
        <button data-action="click->rejection-form#handleProofTypeClick" data-proof-type="residency">Residency Proof</button>
      </div>
    `

    // Set up Stimulus application
    application = Application.start()
    application.register("rejection-form", RejectionFormController)

    element = document.querySelector("[data-controller='rejection-form']")
    incomeOnlyReasons = document.querySelector(".income-only-reasons")
  })

  test("shows income-only reasons when income proof type is selected", () => {
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    const proofTypeInput = controller.proofTypeTarget
    
    const incomeButton = document.querySelector("[data-proof-type='income']")
    incomeButton.click()
    
    expect(proofTypeInput.value).toBe("income")
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(false)
  })

  test("hides income-only reasons when residency proof type is selected", () => {
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    const proofTypeInput = controller.proofTypeTarget
    
    const residencyButton = document.querySelector("[data-proof-type='residency']")
    residencyButton.click()
    
    expect(proofTypeInput.value).toBe("residency")
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(true)
  })

  test("initializes with income-only reasons hidden by default", () => {
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    // The controller's connect method should handle initial visibility
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(true)
  })

  test("updates income-only reasons visibility when proof type changes", () => {
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    const incomeButton = document.querySelector("[data-proof-type='income']")
    const residencyButton = document.querySelector("[data-proof-type='residency']")
    
    incomeButton.click()
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(false)
    
    residencyButton.click()
    expect(incomeOnlyReasons.classList.contains("hidden")).toBe(true)
  })

  test("selects predefined reason text when button is clicked", () => {
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    const proofTypeInput = controller.proofTypeTarget
    const reasonField = controller.reasonFieldTarget
    
    controller.addressMismatchIncomeValue = "Address mismatch income text"
    controller.addressMismatchResidencyValue = "Address mismatch residency text"
    
    const incomeButton = document.querySelector("[data-proof-type='income']")
    incomeButton.click() // Set proofTypeInput.value to "income"
    
    const reasonButton = document.createElement("button")
    reasonButton.dataset.reasonType = "addressMismatch"
    
    controller.selectPredefinedReason({ currentTarget: reasonButton })
    expect(reasonField.value).toBe("Address mismatch income text")
    
    const residencyButton = document.querySelector("[data-proof-type='residency']")
    residencyButton.click() // Set proofTypeInput.value to "residency"
    
    controller.selectPredefinedReason({ currentTarget: reasonButton })
    expect(reasonField.value).toBe("Address mismatch residency text")
  })

  test("validates form submission", () => {
    const controller = application.getControllerForElementAndIdentifier(element, "rejection-form")
    const proofTypeInput = controller.proofTypeTarget
    const reasonField = controller.reasonFieldTarget
    
    const mockEvent = {
      preventDefault: jest.fn()
    }
    
    reasonField.value = ""
    proofTypeInput.value = "income"
    
    controller.validateForm(mockEvent)
    
    expect(mockEvent.preventDefault).toHaveBeenCalled()
    expect(reasonField.classList.contains("border-red-500")).toBe(true)
    
    mockEvent.preventDefault.mockClear()
    
    reasonField.value = "Valid reason"
    
    controller.validateForm(mockEvent)
    
    expect(mockEvent.preventDefault).not.toHaveBeenCalled()
    expect(reasonField.classList.contains("border-red-500")).toBe(false)
  })
})
