import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = {
    data: Object,
    type: String
  }

  connect() {
    this.initializeChart()
  }

  initializeChart() {
    const ctx = this.element.getContext("2d")
    const data = this.dataValue
    
    new Chart(ctx, {
      type: this.typeValue || "bar",
      data: {
        labels: Object.keys(data),
        datasets: [{
          label: "Monthly Total",
          data: Object.values(data),
          backgroundColor: "rgba(79, 70, 229, 0.2)", // Indigo color
          borderColor: "rgba(79, 70, 229, 1)",
          borderWidth: 1
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
            }
          }
        }
      }
    })
  }
}
