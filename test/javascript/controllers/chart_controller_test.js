import { Application } from "@hotwired/stimulus"
import ChartController from "controllers/charts/chart_controller"
import ChartBaseController from "controllers/charts/base_controller" // Import ChartBaseController

// Mock Chart.js
const mockChart = {
  update: jest.fn(),
  destroy: jest.fn(),
  data: {},
  config: { type: 'bar' }
}

// Mock window.Chart (the global Chart instance)
Object.defineProperty(window, 'Chart', {
  value: jest.fn().mockImplementation(() => mockChart),
  writable: true
})

describe("ChartController", () => {
  let application
  let controller
  let element
  let mockCanvas
  let mockContext

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks()

    // Set up DOM
    document.body.innerHTML = `
      <div data-controller="chart"
           data-chart-data-value='{"January 2025": "100.00", "February 2025": "200.00", "March 2025": "150.00"}'
           data-chart-type-value="bar"
           data-chart-aria-label-value="Bar chart showing monthly voucher totals"
           data-chart-aria-description-value="Chart data is available in the table above">
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
      appendChild: jest.fn(),
      style: {}
    }

    // Mock document.createElement
    const originalCreateElement = document.createElement.bind(document)
    document.createElement = jest.fn().mockImplementation((tagName) => {
      if (tagName === 'canvas') {
        return mockCanvas
      } else if (tagName === 'p') {
        return originalCreateElement('p')
      } else if (tagName === 'div') {
        return originalCreateElement('div')
      }
      return originalCreateElement(tagName)
    })

    // Mock appendChild on the controller element
    const mockAppendChild = jest.fn()

    // Set up Stimulus application
    application = Application.start()
    application.register("chart", ChartController)

    element = document.querySelector("[data-controller='chart']")
    element.appendChild = mockAppendChild
  })

  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })

  test("calls createChart on connect", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "chart")

    // Should have created a canvas element
    expect(document.createElement).toHaveBeenCalledWith("canvas")
    expect(document.createElement).toHaveBeenCalledWith("p")
  })

  test("initializes Chart.js with correct data", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "chart")

    // The controller should initialize Chart.js
    expect(window.Chart).toHaveBeenCalled()

    // Get the config object passed to Chart constructor
    const chartConfig = window.Chart.mock.calls[0][1]

    // Check that the data was converted from strings to numbers
    expect(chartConfig.data.datasets[0].data).toEqual([100, 200, 150])

    // Check that the labels are correct
    expect(chartConfig.data.labels).toEqual(["January 2025", "February 2025", "March 2025"])
  })

  test("sets chart type from data attribute", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "chart")

    // The controller should use the chart type from data-chart-type-value
    expect(window.Chart).toHaveBeenCalled()

    // Get the config object passed to Chart constructor
    const chartConfig = window.Chart.mock.calls[0][1]

    // Check that the chart type is correct
    expect(chartConfig.type).toBe("bar")
  })

  test("configures chart with accessibility options", () => {
    // Get the controller instance
    const controller = application.getControllerForElementAndIdentifier(element, "chart")

    // The controller should configure the chart with accessibility options
    expect(window.Chart).toHaveBeenCalled()

    // Get the config object passed to Chart constructor
    const chartConfig = window.Chart.mock.calls[0][1]

    // Check that the chart has proper font sizes for readability
    expect(chartConfig.options.scales.y.ticks.font.size).toBe(14)
    expect(chartConfig.options.scales.x.ticks.font.size).toBe(14)

    // Check that the chart has axis titles
    expect(chartConfig.options.scales.y.title.display).toBe(true)
    expect(chartConfig.options.scales.y.title.text).toBe("Amount in USD")

    expect(chartConfig.options.scales.x.title.display).toBe(true)
    expect(chartConfig.options.scales.x.title.text).toBe("Month")
  })

  test("handles Chart.js unavailability gracefully", () => {
    // Mock console.warn to test unavailable handling
    const consoleWarnSpy = jest.spyOn(console, 'warn').mockImplementation(() => { })

    // Make Chart unavailable
    // Make Chart unavailable by setting it to undefined, as application.js does in test env
    window.Chart = undefined

    // Create a new element
    document.body.innerHTML = `
      <div>
        <div data-controller="chart"
             data-chart-data-value='{"January": "100"}'
             data-chart-type-value="bar">
        </div>
      </div>
    `
    const errorElement = document.querySelector("[data-controller='chart']")

    // Manually instantiate the controller
    // Manually instantiate the controller
    const controller = new ChartController(errorElement)

    // Spy on ChartBaseController.prototype.handleUnavailable to confirm it's called.
    // We will mock its internal call to _showMessage to prevent DOM errors.
    const handleUnavailableSpy = jest.spyOn(ChartBaseController.prototype, 'handleUnavailable');

    // Mock ChartBaseController.prototype._showMessage to prevent it from accessing this.element
    // which is not fully initialized in this isolated test.
    const showMessageSpy = jest.spyOn(ChartBaseController.prototype, '_showMessage').mockImplementation(() => { });

    // Mock super.connect() to prevent it from trying to access DOM properties
    // that are not fully set up in this isolated test scenario.
    const originalSuperConnect = ChartBaseController.prototype.connect;
    ChartBaseController.prototype.connect = jest.fn();

    // Explicitly call connect() on the controller instance
    controller.connect();

    // The controller should handle unavailable Chart and call handleUnavailable
    expect(handleUnavailableSpy).toHaveBeenCalled();
    // And handleUnavailable should have called console.warn (which is spied on globally)
    expect(consoleWarnSpy).toHaveBeenCalledWith("Chart.js not available, skipping chart initialization");
    // And _showMessage should have been called by handleUnavailable
    expect(showMessageSpy).toHaveBeenCalled();

    // Restore original methods
    ChartBaseController.prototype.connect = originalSuperConnect;
    handleUnavailableSpy.mockRestore();
    showMessageSpy.mockRestore();
    consoleWarnSpy.mockRestore();
  })
})
