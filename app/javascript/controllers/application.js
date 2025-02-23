import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// Register the modal controller
import ModalController from "./modal_controller"
application.register("modal", ModalController)

// Register the date input controller
import DateInputController from "./date_input_controller"
application.register("date-input", DateInputController)

export { application }
