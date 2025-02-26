import { Application } from "@hotwired/stimulus"
import ChartController from "controllers/chart_controller"
import Chart from "chart.js/auto"

// Mock Chart.js
jest.mock("chart.js/auto", () => {
  return jest.fn().mockImplementation(() => {
    return {
      update: jest.fn(),
      destroy: jest.fn()
    }
  })
})

describe("ChartController", () => {
  let application
  let controller
  let element
  let mockCanvas
  let mockContext

  beforeEach(() => {
    // Set up DOM
    document.body.innerHTML = `
      <div data-controller="chart"
           data-chart-data-value='{"January 2025": "100.00", "February 2025": "200.00", "March 2025": "150.00"}'
           data-chart-type-value="bar">
      </div>
    `

    // Mock canvas and context
    mockContext = {
      clearRect: jest.fn(),
      fillRect: jest.fn()
    }
    
    mockCanvas = {
      getContext: jest.fn().mockReturnValue(mockContext),
      setAttribute: jest.fn(),
      appendChild: jest.fn()
    }
    
    // Mock document.createElement to return our mock canvas
    document.createElement = jest.fn().mockImplementation((tagName) => {
      if (tagName === 'canvas') {
        return mockCanvas
      }
      return document.createElement.originalFn(tagName)
    })

    // Set up Stimulus controller
    application = Application.start()
    application.register("chart", ChartController)

    element = document.querySelector("[data-controller='chart']")
  })

  test("creates a canvas element with accessibility attributes", () => {
    // Get the controller instance that was automatically created
    const controller = application.getControllerForElementAndIdentifier(element, "chart")
    
    // The connect method should create a canvas with accessibility attributes
    expect(document.createElement).toHaveBeenCalledWith("canvas")
    expect(mockCanvas.setAttribute).toHaveBeenCalledWith("role", "img")
    expect(mockCanvas.setAttribute).toHaveBeenCalledWith("aria-label", "Bar chart showing monthly voucher totals for the past 6 months")
    expect(mockCanvas.setAttribute).toHaveBeenCalledWith("aria-describedby", "chart-description")
  })

  test("adds fallback content to canvas for screen readers", () => {
    // Get the controller instance that was automatically created
    const controller = application.getControllerForElementAndIdentifier(element, "chart")
    
    // The connect method should add fallback text to the canvas
    expect(mockCanvas.appendChild).toHaveBeenCalled()
    const appendedNode = mockCanvas.appendChild.mock.calls[0][0]
    expect(appendedNode.textContent).toContain("Chart showing monthly voucher totals")
  })

  test("initializes Chart.js with correct data", () => {
    // Get the controller instance that was automatically created
    const controller = application.getControllerForElementAndIdentifier(element, "chart")
    
    // The controller should initialize Chart.js with the data from data-chart-data-value
    expect(Chart).toHaveBeenCalled()
    
    // Get the config object passed to Chart constructor
    const chartConfig = Chart.mock.calls[0][1]
    
    // Check that the data was properly converted from strings to numbers
    expect(chartConfig.data.datasets[0].data).toEqual([100, 200, 150])
    
    // Check that the labels are correct
    expect(chartConfig.data.labels).toEqual(["January 2025", "February 2025", "March 2025"])
  })

  test("sets chart type from data attribute", () => {
    // Get the controller instance that was automatically created
    const controller = application.getControllerForElementAndIdentifier(element, "chart")
    
    // The controller should use the chart type from data-chart-type-value
    expect(Chart).toHaveBeenCalled()
    
    // Get the config object passed to Chart constructor
    const chartConfig = Chart.mock.calls[0][1]
    
    // Check that the chart type is correct
    expect(chartConfig.type).toBe("bar")
  })

  test("configures chart with accessibility options", () => {
    // Get the controller instance that was automatically created
    const controller = application.getControllerForElementAndIdentifier(element, "chart")
    
    // The controller should configure the chart with accessibility options
    expect(Chart).toHaveBeenCalled()
    
    // Get the config object passed to Chart constructor
    const chartConfig = Chart.mock.calls[0][1]
    
    // Check that the chart has proper font sizes for readability
    expect(chartConfig.options.scales.y.ticks.font.size).toBe(14)
    expect(chartConfig.options.scales.x.ticks.font.size).toBe(14)
    
    // Check that the chart has axis titles
    expect(chartConfig.options.scales.y.title.display).toBe(true)
    expect(chartConfig.options.scales.y.title.text).toBe("Amount in USD")
    
    expect(chartConfig.options.scales.x.title.display).toBe(true)
    expect(chartConfig.options.scales.x.title.text).toBe("Month")
    
    // Check that the chart has keyboard navigation enabled
    expect(chartConfig.options.interaction.includeInvisible).toBe(true)
  })

  test("handles errors gracefully", () => {
    // Mock console.error to test error handling
    console.error = jest.fn()
    
    // Mock getContext to throw an error
    mockCanvas.getContext = jest.fn().mockImplementation(() => {
      throw new Error("Canvas error")
    })
    
    // Re-initialize the controller to trigger the error
    element.innerHTML = ""
    application.register("chart", ChartController)
    
    // The controller should catch the error and log it
    expect(console.error).toHaveBeenCalled()
    expect(console.error.mock.calls[0][0]).toBe("Error initializing chart:")
  })
})
