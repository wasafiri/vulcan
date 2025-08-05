// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import * as WebAuthnJSON from "@github/webauthn-json"
import Auth from "./auth"
import "./services/notification_service" // Ensure AppNotifications is available globally

// Chart.js setup following official documentation
// Tree-shaken imports for production optimization
import {
  Chart,
  BarController,
  LineController,
  PolarAreaController,
  DoughnutController,
  RadarController,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  CategoryScale,
  LinearScale,
  RadialLinearScale,
  Title,
  Tooltip,
  Legend
} from 'chart.js'

// Register required components per Chart.js docs
Chart.register(
  BarController,
  LineController,
  PolarAreaController,
  DoughnutController,
  RadarController,
  BarElement,
  LineElement,
  PointElement,
  ArcElement,
  CategoryScale,
  LinearScale,
  RadialLinearScale,
  Title,
  Tooltip,
  Legend
)

// Minimal configuration - disable responsive to prevent DOM calculation recursion
Chart.defaults.animation = false
Chart.defaults.responsive = false
Chart.defaults.maintainAspectRatio = false

// Make Chart available globally for controllers
window.Chart = Chart

import "./controllers"

// Make WebAuthnJSON and Auth available globally if needed for debugging, or remove if not
window.WebAuthnJSON = WebAuthnJSON
window.Auth = Auth


console.log("Application.js loaded - Chart.js enabled");

ActiveStorage.start()