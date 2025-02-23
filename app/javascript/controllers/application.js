import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Register the modal controller
import ModalController from "./modal_controller"
application.register("modal", ModalController)

export { application }
import { Application } from "@hotwired/stimulus"

const application = Application.start()

export { application }
