import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = {
    data: Object,
    type: String
  }

  connect() {
    console.log("Chart controller connected")
    try {
      // Create a canvas element dynamically with accessibility attributes
      const canvas = document.createElement('canvas')
      canvas.width = 800
      canvas.height = 300
      canvas.style.width = '100%'
      canvas.style.height = '300px'
      
      // Add accessibility attributes
      canvas.setAttribute('role', 'img')
      canvas.setAttribute('aria-label', 'Bar chart showing monthly voucher totals for the past 6 months')
      canvas.setAttribute('aria-describedby', 'chart-description')
      
      // Add fallback content for screen readers
      const fallbackText = document.createTextNode('Chart showing monthly voucher totals. The data is also available in the table above.')
      canvas.appendChild(fallbackText)
      
      // Clear the container and append the canvas
      this.element.innerHTML = ''
      this.element.appendChild(canvas)
      
      this.initializeChart(canvas)
    } catch (error) {
      console.error("Error initializing chart:", error)
    }
  }

  initializeChart(canvas) {
    // Check if canvas context is available
    let ctx
    try {
      ctx = canvas.getContext("2d")
      console.log("Canvas context:", ctx ? "available" : "not available")
    } catch (error) {
      console.error("Error getting canvas context:", error)
      return
    }
    
    const data = this.dataValue
    console.log("Raw data:", data)
    
    // Convert string values to numbers
    const numericData = {}
    Object.keys(data).forEach(key => {
      numericData[key] = parseFloat(data[key])
    })
    
    console.log("Chart data:", numericData)
    
    new Chart(ctx, {
      type: this.typeValue || "bar",
      data: {
        labels: Object.keys(numericData),
        datasets: [{
          label: "Monthly Total",
          data: Object.values(numericData),
          backgroundColor: "rgba(79, 70, 229, 0.7)", // Increased opacity for better contrast
          borderColor: "rgba(79, 70, 229, 1)",
          borderWidth: 2 // Increased for better visibility
        }]
      },
      options: {
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
                size: 14 // Larger font size for better readability
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
                size: 14 // Larger font size for better readability
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
          // Enable keyboard navigation
          includeInvisible: true
        }
      }
    })
  }
}
