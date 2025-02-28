// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import Chart from "chart.js/auto"
import "./controllers"
import "./controllers/debug_helper"

// Make Chart.js available globally
window.Chart = Chart

ActiveStorage.start()
