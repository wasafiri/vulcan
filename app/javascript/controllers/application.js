import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

// The controllers are registered in index.js to avoid duplicate registrations
// Do not register controllers here directly

export { application }
