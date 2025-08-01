// chart_controller.js

import ChartBaseController from "./base_controller"

/**
 * Chart Controller (v3)
 *
 * Builds on ChartBaseController's safeguards and restores full "responsive" behavior
 * and basic animations for visual interest.
 */
export default class extends ChartBaseController {
  static values = {
    data: Object,
    type: { type: String, default: "bar" },
    ariaLabel: { type: String, default: "Chart visualization" },
    ariaDescription: { type: String, default: "Chart data is available in the table above" },
    chartHeight: { type: Number, default: 300 },
    datasetLabel: { type: String, default: "Monthly Total" }
  }

  connect() {
    super.connect()

    const Chart = this.getChart()
    if (!Chart) {
      return this.handleUnavailable()
    }

    if (!this.validateData(this.dataValue)) {
      return
    }

    try {
      this.createChart()
    } catch (error) {
      this.handleError("Error initializing chart", error)
    }
  }

  // When the dataValue changes, destroy/recreate the chart
  dataValueChanged() {
    if (this.chartInstance && this.validateData(this.dataValue)) {
      this.cleanupExistingChart()
      this.createChart()
    }
  }

  // Called by the base‐controller's debounced resize handler
  recreateChart() {
    if (this.validateData(this.dataValue)) {
      // Destroy first to avoid overflows, then redraw at new width
      this.cleanupExistingChart()
      this.createChart()
    }
  }

  createChart() {
    const Chart = this.getChart()

    // 1) Create a new <canvas> (sized to the current container)
    // 2) Mount it (wipes any previous chart + description)
    const { canvas, desc } = this.createCanvas(
      this.ariaLabelValue,
      this.ariaDescriptionValue
    )
    this.mountCanvas(canvas, desc)

    // 3) Grab the 2D drawing context
    const ctx = this.getCtx(canvas)
    if (!ctx) {
      return
    }

    // 4) Turn string values into numbers (with fallback to 0)
    const numericData = this.prepareChartData()

    // 5) Build an "animated" override on top of base defaults
    const responsiveOverrides = {
      animation: {
        duration: 800,
        easing: "easeOutQuart"
      }
    }

    // 6) Custom plugin/scale settings (legends, tooltips, axis labels, etc.)
    const customOptions = {
      plugins: {
        legend: {
          display: true,
          labels: {
            font: { size: 14 }
          }
        },
        tooltip: {
          callbacks: {
            label: function (context) {
              return "$" + context.raw.toLocaleString()
            }
          },
          bodyFont: { size: 14 },
          titleFont: { size: 16 }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          ticks: {
            callback: function (value) {
              return "$" + value.toLocaleString()
            },
            font: { size: 14 }
          },
          title: {
            display: true,
            text: "Amount in USD",
            font: { size: 16, weight: "bold" }
          }
        },
        x: {
          ticks: {
            font: { size: 14 }
          },
          title: {
            display: true,
            text: "Month",
            font: { size: 16, weight: "bold" }
          }
        }
      }
    }

    // 7) Merge everything: base defaults → responsive overrides → our custom bits
    const baseOptions = this.getDefaultOptions()
    const finalOptions = this.mergeOptions(
      baseOptions,
      Object.assign({}, responsiveOverrides, customOptions)
    )

    // 8) Finally instantiate the Chart
    this.chartInstance = new Chart(ctx, {
      type: this.typeValue,
      data: {
        labels: Object.keys(numericData),
        datasets: [
          {
            label: this.datasetLabelValue,
            data: Object.values(numericData),
            backgroundColor: "rgba(79, 70, 229, 0.7)",
            borderColor: "rgba(79, 70, 229, 1)",
            borderWidth: 2
          }
        ]
      },
      options: finalOptions
    })
  }

  prepareChartData() {
    const data = this.dataValue || {}
    const numericData = {}

    Object.keys(data).forEach((key) => {
      const parsed = parseFloat(data[key])
      numericData[key] = isNaN(parsed) ? 0 : parsed
    })

    return numericData
  }
}
