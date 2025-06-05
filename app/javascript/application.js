// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import { Chart, registerables } from "chart.js"
import * as WebAuthnJSON from "@github/webauthn-json"
import Auth from "./auth"

// Register Chart.js components
Chart.register(...registerables)

if (process.env.NODE_ENV !== "test") {
  // dev/prod path - Chart.js with manual resize handling to prevent infinite loops
  Chart.defaults.responsive = false
  Chart.defaults.maintainAspectRatio = false
  Chart.defaults.animation = false

  // Make it available to your controllers
  window.Chart = Chart
} else {
  // test path - disable Chart.js completely
  window.Chart = undefined
}

import "./controllers"

// Make WebAuthnJSON and Auth available globally if needed for debugging, or remove if not
window.WebAuthnJSON = WebAuthnJSON
window.Auth = Auth

// Log when application.js is loaded
if (process.env.NODE_ENV !== 'production') {
  console.log("Application.js loaded - password visibility is now handled by Stimulus visibility controller");
  console.log("Chart.js configured with explicit canvas dimensions to prevent getComputedStyle loops");
}

ActiveStorage.start()
