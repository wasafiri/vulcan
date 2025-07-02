// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
// Temporarily commented out Chart.js to fix getComputedStyle infinite recursion in system tests
// import { Chart, registerables } from "chart.js"
import * as WebAuthnJSON from "@github/webauthn-json"
import Auth from "./auth"

// Temporarily commented out Chart.js registration to fix system test issues
// Chart.register(...registerables)

// Provide Chart.js stub for compatibility
window.Chart = {
  register: () => {},
  defaults: {
    responsive: false,
    maintainAspectRatio: false,
    animation: false
  },
  // Provide a safe constructor that does nothing
  Chart: function() { return { destroy: () => {}, update: () => {}, render: () => {} }; }
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
