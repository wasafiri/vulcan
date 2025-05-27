import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

/**
 * Chart Controller
 * 
 * Renders Chart.js charts with accessibility features, error handling, and proper cleanup.
 * Supports configurable dimensions, ARIA labels, dataset labels, and memory leak prevention.
 */
export default class extends Controller {
  static values = {
    data: Object,
    type: { type: String, default: "bar" },
    ariaLabel: { type: String, default: "Chart visualization" },
    ariaDescription: { type: String, default: "Chart data is available in the table above" },
    width: { type: Number, default: 800 },
    height: { type: Number, default: 300 },
    datasetLabel: { type: String, default: "Data" }
  }

  connect() {
    // Clean up any existing chart instance first
    this.cleanupExistingChart()
    
    // Skip chart initialization if Chart.js is not available
    if (typeof Chart === 'undefined') {
      this.handleChartUnavailable()
      return
    }
    
    try {
      this.createChart()
    } catch (error) {
      this.handleError("Error initializing chart", error)
    }
  }

  disconnect() {
    // Clean up chart instance when controller disconnects
    this.cleanupExistingChart()
  }

  createChart() {
    const canvas = this.createCanvas()
    const fallbackElement = this.createFallbackElement()
    this.setupContainer(canvas, fallbackElement)
    this.initializeChart(canvas)
  }

  createCanvas() {
    const canvas = document.createElement('canvas')
    canvas.width = this.widthValue
    canvas.height = this.heightValue
    canvas.style.width = '100%'
    canvas.style.height = this.heightValue + 'px'
    
    // Generate unique ID for aria-describedby link with collision prevention
    const baseId = this.element.id || `chart-${Date.now()}`
    const randomSuffix = Math.random().toString(36).substring(2, 8)
    const fallbackId = `chart-description-${baseId}-${randomSuffix}`
    
    // Add accessibility attributes
    canvas.setAttribute('role', 'img')
    canvas.setAttribute('aria-label', this.ariaLabelValue)
    canvas.setAttribute('aria-describedby', fallbackId)
    
    // Store fallback ID for later use
    this.fallbackId = fallbackId
    
    return canvas
  }

  createFallbackElement() {
    // Create visually hidden paragraph for screen readers
    const fallbackElement = document.createElement('p')
    fallbackElement.id = this.fallbackId
    fallbackElement.className = 'sr-only'
    fallbackElement.textContent = this.ariaDescriptionValue
    
    return fallbackElement
  }

  setupContainer(canvas, fallbackElement) {
    // Clear the container and append both canvas and fallback
    this.element.textContent = ''
    this.element.appendChild(canvas)
    this.element.appendChild(fallbackElement)
  }

  initializeChart(canvas) {
    const ctx = this.getCanvasContext(canvas)
    if (!ctx) return

    const chartData = this.prepareChartData()
    this.renderChart(ctx, chartData)
  }

  getCanvasContext(canvas) {
    try {
      const ctx = canvas.getContext("2d")
      if (!ctx) {
        this.handleError("Canvas context not available")
        return null
      }
      return ctx
    } catch (error) {
      this.handleError("Error getting canvas context", error)
      return null
    }
  }

  prepareChartData() {
    const data = this.dataValue
    
    // Convert string values to numbers
    const numericData = {}
    Object.keys(data).forEach(key => {
      numericData[key] = parseFloat(data[key])
    })
    
    return numericData
  }

  renderChart(ctx, numericData) {
    // Store chart instance for proper cleanup
    this.chartInstance = new Chart(ctx, {
      type: this.typeValue,
      data: {
        labels: Object.keys(numericData),
        datasets: [{
          label: this.datasetLabelValue,
          data: Object.values(numericData),
          backgroundColor: "rgba(79, 70, 229, 0.7)",
          borderColor: "rgba(79, 70, 229, 1)",
          borderWidth: 2
        }]
      },
      options: this.getChartOptions()
    })
  }

  getChartOptions() {
    return {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            callback: function(value) {
              return "$" + value.toLocaleString()
            },
            font: {
              size: 14
            }
          },
          title: {
            display: true,
            text: 'Amount in USD',
            font: {
              size: 16,
              weight: 'bold'
            }
          }
        },
        x: {
          ticks: {
            font: {
              size: 14
            }
          },
          title: {
            display: true,
            text: 'Month',
            font: {
              size: 16,
              weight: 'bold'
            }
          }
        }
      },
      plugins: {
        tooltip: {
          callbacks: {
            label: function(context) {
              return "$" + context.raw.toLocaleString()
            }
          },
          bodyFont: {
            size: 14
          },
          titleFont: {
            size: 16
          }
        },
        legend: {
          labels: {
            font: {
              size: 14
            }
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

  cleanupExistingChart() {
    if (this.chartInstance) {
      this.chartInstance.destroy()
      this.chartInstance = null
    }
  }

  handleChartUnavailable() {
    console.warn("Chart.js not available, skipping chart initialization")
    this.clearAndShowMessage('text-gray-500', 'Chart unavailable – ' + this.ariaDescriptionValue)
  }

  handleError(message, error) {
    console.error(message, error || "Unknown error")
    this.clearAndShowMessage('text-red-500', 'Unable to load chart – ' + this.ariaDescriptionValue)
  }

  clearAndShowMessage(colorClass, message) {
    // Clear container without wiping out attached controllers
    this.element.textContent = ''
    
    // Create message element using DOM methods
    const messageDiv = document.createElement('div')
    messageDiv.className = colorClass + ' text-center p-4'
    messageDiv.textContent = message
    
    this.element.appendChild(messageDiv)
  }
}
