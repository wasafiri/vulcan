import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    currentData: Object,
    previousData: Object,
    type: String,
    title: String,
    compact: { type: Boolean, default: false },
    yAxisLabel: { type: String, default: 'Count' }
  }

  connect() {
    console.log("Reports chart controller connected")
    
    // Store a reference to the element for later use
    this.chartContainer = this.element
    
    // Check if the element is visible
    if (this.isElementVisible(this.chartContainer)) {
      this.initializeChart()
    } else {
      console.log("Chart container is hidden, deferring initialization")
      // Set up a mutation observer to detect when the element becomes visible
      this.setupVisibilityObserver()
      
      // Also listen for the custom visibility-changed event
      this.boundVisibilityHandler = this.handleVisibilityChanged.bind(this)
      document.addEventListener('visibility-changed', this.boundVisibilityHandler)
    }
  }
  
  handleVisibilityChanged(event) {
    console.log("Visibility changed event received", event)
    if (event.detail && event.detail.visible) {
      // Check if the chart container is now visible
      if (this.isElementVisible(this.chartContainer)) {
        console.log("Chart container is now visible via event, initializing chart")
        this.initializeChart()
        
        // Remove the event listener since we've initialized the chart
        document.removeEventListener('visibility-changed', this.boundVisibilityHandler)
      }
    }
  }
  
  isElementVisible(element) {
    // Check if the element is visible in the DOM
    return element.offsetParent !== null && 
           !element.closest('.hidden') && 
           window.getComputedStyle(element).display !== 'none'
  }
  
  setupVisibilityObserver() {
    // Create a new MutationObserver to watch for class changes
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && 
            (mutation.attributeName === 'class' || mutation.attributeName === 'style')) {
          // Check if the element is now visible
          if (this.isElementVisible(this.chartContainer)) {
            console.log("Chart container is now visible, initializing chart")
            this.initializeChart()
            // Disconnect the observer once the chart is initialized
            this.observer.disconnect()
          }
        }
      })
    })
    
    // Start observing the element for attribute changes
    this.observer.observe(this.chartContainer, { 
      attributes: true,
      attributeFilter: ['class', 'style']
    })
    
    // Also observe the parent elements up to 3 levels
    let parent = this.chartContainer.parentElement
    for (let i = 0; i < 3 && parent; i++) {
      this.observer.observe(parent, { 
        attributes: true,
        attributeFilter: ['class', 'style']
      })
      parent = parent.parentElement
    }
  }

  initializeChart() {
    try {
      console.log("Initializing chart...")
      
      // Check if Chart.js is available
      if (typeof Chart === 'undefined') {
        console.error("Chart.js is not available")
        this.chartContainer.innerHTML = '<p class="text-red-500">Chart could not be loaded. Chart.js is not available.</p>'
        return
      }
      
      console.log("Chart.js is available, creating chart with type:", this.typeValue)
      
      // Create a canvas element with accessibility attributes
      const canvas = document.createElement('canvas')
      const chartId = `chart-${Math.random().toString(36).substring(2, 9)}`
      canvas.id = chartId
      
      // Set canvas size based on compact mode
      if (this.hasCompactValue && this.compactValue) {
        canvas.width = 400
        canvas.height = 200
        canvas.style.width = '100%'
        canvas.style.height = '200px'
      } else {
        canvas.width = 800
        canvas.height = 300
        canvas.style.width = '100%'
        canvas.style.height = '300px'
      }
      
      // Add accessibility attributes
      canvas.setAttribute('role', 'img')
      canvas.setAttribute('aria-label', `${this.titleValue || 'Comparison chart'} showing current and previous fiscal year data`)
      
      // Add fallback content for screen readers
      const fallbackText = document.createTextNode(`Chart comparing current and previous fiscal year data.`)
      canvas.appendChild(fallbackText)
      
      // Clear the container and append the canvas
      this.chartContainer.innerHTML = ''
      this.chartContainer.appendChild(canvas)
      
      // Get the context and create the chart
      const ctx = canvas.getContext("2d")
      if (!ctx) {
        console.error("Could not get canvas context")
        return
      }
      
      // Parse the data values
      let currentData, previousData
      try {
        currentData = this.currentDataValue
        previousData = this.previousDataValue
        
        console.log("Current data:", currentData)
        console.log("Previous data:", previousData)
      } catch (error) {
        console.error("Error parsing data:", error)
        return
      }
      
      // Get the chart type
      const chartType = this.typeValue || "bar"
      
      // Configure chart based on type
      let chartConfig = this.getChartConfig(chartType, currentData, previousData)
      
      // Create the chart
      new Chart(ctx, chartConfig)
      
      console.log("Chart created successfully")
    } catch (error) {
      console.error("Error initializing chart:", error)
      this.chartContainer.innerHTML = '<p class="text-red-500">Error creating chart. Please check the console for details.</p>'
    }
  }
  
  getChartConfig(chartType, currentData, previousData) {
    // Common dataset configuration
    const currentDataset = {
      label: "Current Fiscal Year",
      data: Object.values(currentData),
      backgroundColor: "rgba(79, 70, 229, 0.7)",
      borderColor: "rgba(79, 70, 229, 1)",
      borderWidth: 2
    }
    
    const previousDataset = {
      label: "Previous Fiscal Year",
      data: Object.values(previousData),
      backgroundColor: "rgba(156, 163, 175, 0.7)",
      borderColor: "rgba(156, 163, 175, 1)",
      borderWidth: 2
    }
    
    // Base configuration
    const baseConfig = {
      type: chartType,
      data: {
        labels: Object.keys(currentData),
        datasets: [currentDataset, previousDataset]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: !(this.hasCompactValue && this.compactValue),
            text: this.titleValue || 'Comparison Chart',
            font: { size: (this.hasCompactValue && this.compactValue) ? 14 : 18, weight: 'bold' }
          },
          legend: {
            display: !(this.hasCompactValue && this.compactValue),
            labels: { font: { size: (this.hasCompactValue && this.compactValue) ? 12 : 14 } }
          },
          tooltip: {
            enabled: true
          }
        },
        interaction: {
          mode: 'index',
          intersect: false,
          includeInvisible: true
        }
      }
    }
    
    // Customize based on chart type
    switch (chartType) {
      case 'bar':
        baseConfig.options.scales = {
          y: {
            beginAtZero: true,
            ticks: {
              font: { size: (this.hasCompactValue && this.compactValue) ? 10 : 14 }
            },
            title: {
              display: !(this.hasCompactValue && this.compactValue),
              text: this.hasYAxisLabelValue ? this.yAxisLabelValue : 'Count',
              font: { size: (this.hasCompactValue && this.compactValue) ? 12 : 16, weight: 'bold' }
            }
          },
          x: {
            ticks: { font: { size: (this.hasCompactValue && this.compactValue) ? 10 : 14 } },
            title: {
              display: !(this.hasCompactValue && this.compactValue),
              text: 'Category',
              font: { size: (this.hasCompactValue && this.compactValue) ? 12 : 16, weight: 'bold' }
            }
          }
        }
        break
        
      case 'horizontalBar':
        baseConfig.type = 'bar' // Chart.js v3+ uses 'bar' with indexAxis: 'y'
        baseConfig.options.indexAxis = 'y'
        baseConfig.options.scales = {
          x: {
            beginAtZero: true,
            ticks: {
              font: { size: (this.hasCompactValue && this.compactValue) ? 10 : 14 }
            },
            title: {
              display: !(this.hasCompactValue && this.compactValue),
              text: this.hasYAxisLabelValue ? this.yAxisLabelValue : 'Count',
              font: { size: (this.hasCompactValue && this.compactValue) ? 12 : 16, weight: 'bold' }
            }
          },
          y: {
            ticks: { font: { size: (this.hasCompactValue && this.compactValue) ? 10 : 14 } },
            title: {
              display: !(this.hasCompactValue && this.compactValue),
              text: 'Category',
              font: { size: (this.hasCompactValue && this.compactValue) ? 12 : 16, weight: 'bold' }
            }
          }
        }
        break
        
      case 'radar':
        // Radar charts don't use the same scales configuration
        baseConfig.options.scales = undefined
        baseConfig.options.elements = {
          line: {
            borderWidth: 3
          }
        }
        // Add patterns for accessibility
        currentDataset.pointBackgroundColor = "rgba(79, 70, 229, 1)"
        previousDataset.pointBackgroundColor = "rgba(156, 163, 175, 1)"
        break
        
      case 'pie':
      case 'doughnut':
        // Pie/doughnut charts need different dataset structure
        baseConfig.data.datasets = [{
          label: 'Data',
          data: [
            Object.values(currentData).reduce((a, b) => a + b, 0),
            Object.values(previousData).reduce((a, b) => a + b, 0)
          ],
          backgroundColor: [
            "rgba(79, 70, 229, 0.7)",
            "rgba(156, 163, 175, 0.7)"
          ],
          borderColor: [
            "rgba(79, 70, 229, 1)",
            "rgba(156, 163, 175, 1)"
          ],
          borderWidth: 2
        }]
        baseConfig.data.labels = ['Current Fiscal Year', 'Previous Fiscal Year']
        break
        
      case 'polarArea':
        // Polar area charts need different dataset structure
        baseConfig.data.datasets = [{
          label: 'Data',
          data: [
            ...Object.values(currentData),
            ...Object.values(previousData)
          ],
          backgroundColor: [
            "rgba(79, 70, 229, 0.7)",
            "rgba(59, 130, 246, 0.7)",
            "rgba(156, 163, 175, 0.7)",
            "rgba(107, 114, 128, 0.7)"
          ],
          borderColor: [
            "rgba(79, 70, 229, 1)",
            "rgba(59, 130, 246, 1)",
            "rgba(156, 163, 175, 1)",
            "rgba(107, 114, 128, 1)"
          ],
          borderWidth: 2
        }]
        
        // Create combined labels for polar area chart
        const combinedLabels = []
        Object.keys(currentData).forEach(key => {
          combinedLabels.push(`${key} (Current FY)`)
        })
        Object.keys(previousData).forEach(key => {
          combinedLabels.push(`${key} (Previous FY)`)
        })
        baseConfig.data.labels = combinedLabels
        break
        
      case 'line':
        // Line charts need additional configuration
        currentDataset.fill = false
        previousDataset.fill = false
        baseConfig.options.scales = {
          y: {
            beginAtZero: true,
            ticks: {
              font: { size: (this.hasCompactValue && this.compactValue) ? 10 : 14 }
            },
            title: {
              display: !(this.hasCompactValue && this.compactValue),
              text: this.hasYAxisLabelValue ? this.yAxisLabelValue : 'Count',
              font: { size: (this.hasCompactValue && this.compactValue) ? 12 : 16, weight: 'bold' }
            }
          },
          x: {
            ticks: { font: { size: (this.hasCompactValue && this.compactValue) ? 10 : 14 } },
            title: {
              display: !(this.hasCompactValue && this.compactValue),
              text: 'Category',
              font: { size: (this.hasCompactValue && this.compactValue) ? 12 : 16, weight: 'bold' }
            }
          }
        }
        break
    }
    
    return baseConfig
  }
  
  disconnect() {
    // Clean up the observer when the controller is disconnected
    if (this.observer) {
      this.observer.disconnect()
    }
    
    // Remove the event listener if it exists
    if (this.boundVisibilityHandler) {
      document.removeEventListener('visibility-changed', this.boundVisibilityHandler)
    }
  }
}
