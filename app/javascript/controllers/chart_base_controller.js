import { Controller } from "@hotwired/stimulus"
import { createUIUpdateDebounce } from "../utils/debounce"

/**
 * ChartBaseController
 * 
 * Base class for Chart.js controllers that provides common functionality:
 * - Canvas creation with accessibility features
 * - Chart instance cleanup
 * - Error handling
 * - Consistent ARIA labeling
 * - Centralized chart defaults
 * - Data validation
 * - Fixed sizing to prevent getComputedStyle loops
 */
export default class ChartBaseController extends Controller {
  static values = {
    chartHeight: { type: Number, default: 300 }
  }

  connect() {
    this.cleanupExistingChart()
    
    // Set explicit container dimensions to break CSS dependency chains
    this.setFixedContainerSize()
    
    // Set up debounced resize handler for fluid responsiveness
    this._onWindowResize = createUIUpdateDebounce(() => {
      if (this.chartInstance && this.element.offsetParent !== null) {
        this.handleResize()
      }
    })
    
    window.addEventListener("resize", this._onWindowResize)
  }

  disconnect() {
    this.cleanupExistingChart()
    window.removeEventListener("resize", this._onWindowResize)
  }

  cleanupExistingChart() {
    if (this.chartInstance) {
      this.chartInstance.destroy()
      this.chartInstance = null
    }
  }

  // Set fixed container dimensions to prevent CSS layout loops
  setFixedContainerSize() {
    // Calculate a reasonable fixed width based on parent container
    const parentWidth = this.element.parentElement?.clientWidth || 400
    const chartWidth = Math.min(parentWidth - 20, 800) // Leave some margin
    
    // Apply fixed dimensions to prevent getComputedStyle loops
    this.element.style.width = chartWidth + 'px'
    this.element.style.height = this.chartHeightValue + 'px'
    this.element.style.position = 'relative'
    this.element.style.overflow = 'hidden'
  }

  // Handle resize by updating container size and recreating chart
  handleResize() {
    if (!this.chartInstance || !this.element.offsetParent) return
    
    const parentWidth = this.element.parentElement?.clientWidth || 400
    const newChartWidth = Math.min(parentWidth - 20, 800)
    const currentWidth = parseInt(this.element.style.width)
    
    // Only resize if width changed significantly
    if (Math.abs(newChartWidth - currentWidth) > 10) {
      // Update container size
      this.element.style.width = newChartWidth + 'px'
      
      // Recreate chart with new dimensions
      this.recreateChart()
    }
  }

  // Recreate chart with current data - to be overridden by child controllers
  recreateChart() {
    console.warn('recreateChart should be overridden by child controller')
  }

  // Defensive data validation
  validateData(data, context = "chart data") {
    if (!data || typeof data !== "object" || !Object.keys(data).length) {
      this.handleError(`No valid ${context} provided`)
      return false
    }
    return true
  }

  createCanvas(ariaLabel, ariaDesc) {
    const canvas = document.createElement("canvas")
    
    // Use container's fixed dimensions to prevent getComputedStyle calls
    const containerWidth = parseInt(this.element.style.width) || 400
    const height = this.chartHeightValue
    
    // CRITICAL FIX: Set HTML width/height attributes to prevent Chart.js getComputedStyle loops
    // This is what Chart.js checks for to avoid forced reflows
    canvas.setAttribute('width', containerWidth.toString())
    canvas.setAttribute('height', height.toString())
    
    // Also set the canvas properties for proper resolution
    canvas.width = containerWidth
    canvas.height = height
    
    // Set CSS styles for display (optional but good for consistency)
    canvas.style.width = containerWidth + 'px'
    canvas.style.height = height + 'px'
    canvas.style.display = 'block'
    
    // Add accessibility attributes
    canvas.setAttribute("role", "img")
    canvas.setAttribute("aria-label", ariaLabel)
    
    // Generate unique ID for aria-describedby with collision prevention
    const baseId = this.element.id || `chart-${Date.now()}`
    const randomSuffix = Math.random().toString(36).substring(2, 6)
    const descId = `chart-desc-${baseId}-${randomSuffix}`
    canvas.setAttribute("aria-describedby", descId)
    
    // Store for cleanup
    this._descId = descId

    // Create screen reader description
    const desc = document.createElement("p")
    desc.id = descId
    desc.className = "sr-only"
    desc.textContent = ariaDesc

    return { canvas, desc }
  }

  mountCanvas(canvas, desc) {
    // Clear container and mount canvas with description
    this.element.textContent = ""
    this.element.appendChild(canvas)
    this.element.appendChild(desc)
  }

  getCtx(canvas) {
    try {
      const ctx = canvas.getContext("2d")
      if (!ctx) {
        this.handleError("Canvas context not available")
        return null
      }
      return ctx
    } catch (error) {
      this.handleError("Canvas context failure", error)
      return null
    }
  }

  handleError(msg, err) {
    console.error(msg, err || "Unknown error")
    this._showMessage("text-red-500", `Unable to load chart – ${msg}`)
  }

  handleUnavailable() {
    console.warn("Chart.js not available, skipping chart initialization")
    this._showMessage("text-gray-500", "Chart unavailable")
  }

  _showMessage(colorClass, text) {
    // Clear container without wiping out attached controllers
    this.element.textContent = ""
    
    const div = document.createElement("div")
    div.className = `${colorClass} text-center p-4`
    div.textContent = text
    
    this.element.appendChild(div)
  }

  // Helper method to get Chart.js with global instance (ensures patches apply)
  getChart() {
    // Use globally configured Chart instance to ensure our patches apply
    return window.Chart
  }

  // Centralized default chart options
  getDefaultOptions() {
    return {
      responsive: false,
      maintainAspectRatio: false,
      animation: false,
      plugins: {
        title: {
          display: false,
          font: { size: 16, weight: 'bold' }
        },
        legend: {
          display: true,
          position: 'top',
          labels: {
            font: { size: 14 }
          }
        },
        tooltip: {
          bodyFont: { size: 14 },
          titleFont: { size: 16 }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            font: { size: 14 }
          },
          title: {
            display: false,
            font: { size: 16, weight: 'bold' }
          }
        },
        x: {
          beginAtZero: true,
          ticks: {
            font: { size: 14 }
          },
          title: {
            display: false,
            font: { size: 16, weight: 'bold' }
          }
        }
      },
      interaction: {
        mode: 'index',
        intersect: false,
        includeInvisible: true
      }
    }
  }

  // Deep merge helper for chart options
  mergeOptions(defaultOptions, customOptions) {
    const result = JSON.parse(JSON.stringify(defaultOptions))
    
    function deepMerge(target, source) {
      for (const key in source) {
        if (source[key] && typeof source[key] === 'object' && !Array.isArray(source[key])) {
          target[key] = target[key] || {}
          deepMerge(target[key], source[key])
        } else {
          target[key] = source[key]
        }
      }
    }
    
    deepMerge(result, customOptions)
    return result
  }
}
