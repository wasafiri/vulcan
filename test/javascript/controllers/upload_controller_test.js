import { Application } from "@hotwired/stimulus"
import UploadController from "controllers/upload_controller"
import { DirectUpload } from "@rails/activestorage"

describe("UploadController", () => {
  let application
  let controller
  let element
  let progressBar
  let submitButton
  let cancelButton
  let fileInput

  beforeEach(() => {
    // Set up DOM
    document.body.innerHTML = `
      <form data-controller="upload">
        <input type="file" data-upload-target="input">
        <div data-upload-target="progress" class="hidden">
          <div role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100"></div>
        </div>
        <button type="submit" data-upload-target="submit">Submit</button>
        <button type="button" data-upload-target="cancel" class="hidden">Cancel Upload</button>
      </form>
    `

    // Set up Stimulus controller
    application = Application.start()
    application.register("upload", UploadController)

    element = document.querySelector("[data-controller='upload']")
    progressBar = element.querySelector("[data-upload-target='progress']")
    submitButton = element.querySelector("[data-upload-target='submit']")
    cancelButton = element.querySelector("[data-upload-target='cancel']")
    fileInput = element.querySelector("[data-upload-target='input']")

    // Mock DirectUpload
    global.DirectUpload = jest.fn().mockImplementation(() => ({
      create: jest.fn().mockResolvedValue({ signed_id: "123" }),
      directUploadWillStoreFileWithXHR: jest.fn(),
    }))
  })

  test("shows progress bar when file selected", () => {
    const file = new File(["content"], "test.pdf", { type: "application/pdf" })
    const event = { target: { files: [file] } }

    controller.handleFileSelect(event)

    expect(progressBar).not.toHaveClass("hidden")
    expect(cancelButton).not.toHaveClass("hidden")
  })

  test("updates progress during upload", () => {
    const file = new File(["content"], "test.pdf", { type: "application/pdf" })
    const xhr = {
      upload: {
        addEventListener: jest.fn()
      }
    }

    controller.handleFileSelect({ target: { files: [file] } })
    controller.bindProgressEvents(xhr)

    // Simulate progress event
    const progressEvent = new Event("progress")
    progressEvent.loaded = 50
    progressEvent.total = 100
    xhr.upload.addEventListener.mock.calls[0][1](progressEvent)

    const progressElement = progressBar.querySelector("[role='progressbar']")
    expect(progressElement.getAttribute("aria-valuenow")).toBe("50")
  })

  test("handles upload cancellation", () => {
    const file = new File(["content"], "test.pdf", { type: "application/pdf" })
    const xhr = {
      abort: jest.fn(),
      upload: {
        addEventListener: jest.fn()
      }
    }

    controller.handleFileSelect({ target: { files: [file] } })
    controller.bindProgressEvents(xhr)
    controller.cancelUpload()

    expect(xhr.abort).toHaveBeenCalled()
    expect(progressBar).toHaveClass("hidden")
    expect(cancelButton).toHaveClass("hidden")
  })

  test("disables submit button during upload", () => {
    const file = new File(["content"], "test.pdf", { type: "application/pdf" })
    
    controller.handleFileSelect({ target: { files: [file] } })
    
    expect(submitButton).toBeDisabled()
  })

  test("enables submit button after upload completes", async () => {
    const file = new File(["content"], "test.pdf", { type: "application/pdf" })
    
    await controller.handleFileSelect({ target: { files: [file] } })
    
    expect(submitButton).not.toBeDisabled()
  })

  test("handles upload errors", async () => {
    const file = new File(["content"], "test.pdf", { type: "application/pdf" })
    global.DirectUpload = jest.fn().mockImplementation(() => ({
      create: jest.fn().mockRejectedValue(new Error("Upload failed")),
      directUploadWillStoreFileWithXHR: jest.fn(),
    }))

    await controller.handleFileSelect({ target: { files: [file] } })

    expect(document.querySelector(".flash.alert")).toBeInTheDocument()
    expect(submitButton).not.toBeDisabled()
  })

  test("announces progress to screen readers", () => {
    const file = new File(["content"], "test.pdf", { type: "application/pdf" })
    const xhr = {
      upload: {
        addEventListener: jest.fn()
      }
    }

    controller.handleFileSelect({ target: { files: [file] } })
    controller.bindProgressEvents(xhr)

    // Simulate progress event
    const progressEvent = new Event("progress")
    progressEvent.loaded = 75
    progressEvent.total = 100
    xhr.upload.addEventListener.mock.calls[0][1](progressEvent)

    const announcement = document.querySelector("[aria-live='polite']")
    expect(announcement.textContent).toContain("75%")
  })
})
