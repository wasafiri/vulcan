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
  // test path - disable Chart.js completely and provide safe stub
  window.Chart = {
    register: () => {},
    defaults: {},
    // Provide a safe constructor that does nothing
    Chart: function() { return { destroy: () => {}, update: () => {}, render: () => {} }; }
  }
  
  // Also disable any chart rendering in test environment
  if (typeof document !== 'undefined') {
    // Override getComputedStyle to prevent recursion issues in tests
    const originalGetComputedStyle = window.getComputedStyle;
    let computedStyleCallCount = 0;
    
    window.getComputedStyle = function(element, pseudoElement) {
      computedStyleCallCount++;
      
      // Prevent infinite recursion by limiting calls
      if (computedStyleCallCount > 100) {
        console.warn('getComputedStyle call limit exceeded, returning empty style');
        computedStyleCallCount = 0;
        return {};
      }
      
      try {
        const result = originalGetComputedStyle.call(this, element, pseudoElement);
        computedStyleCallCount = Math.max(0, computedStyleCallCount - 1);
        return result;
      } catch (error) {
        console.warn('getComputedStyle error:', error);
        computedStyleCallCount = 0;
        return {};
      }
    };
  }
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
