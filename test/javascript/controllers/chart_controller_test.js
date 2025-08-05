import ReportsChartController from 'controllers/charts/reports_chart_controller';

// Mock the global Chart object and its instance
const mockChartInstance = {
  destroy: jest.fn(),
  update: jest.fn(),
  data: {
    labels: [],
    datasets: [{ data: [] }, { data: [] }],
  },
};
window.Chart = jest.fn().mockImplementation(() => mockChartInstance);
window.requestAnimationFrame = (cb) => {
  if (cb) cb();
  return 1;
};

// JSDOM doesn't implement getContext, so we mock it.
HTMLCanvasElement.prototype.getContext = () => ({
  clearRect: () => {},
  fillRect: () => {},
});

describe('ReportsChartController', () => {
  let element;
  let controller;

  beforeEach(async () => {
    jest.clearAllMocks();

    document.body.innerHTML = `
      <div 
        data-reports-chart-current-data-value='{"Submitted": 10, "Draft": 5}'
        data-reports-chart-previous-data-value='{"Submitted": 8, "Draft": 3}'
        data-reports-chart-type-value="bar"
        data-reports-chart-chart-height-value="250"
      ></div>
    `;
    element = document.querySelector('div');
    
    Object.defineProperty(element, 'clientWidth', { value: 400, configurable: true });

    controller = new ReportsChartController();

    Object.defineProperty(controller, 'element', { value: element, configurable: true });
    Object.defineProperty(controller, 'currentDataValue', { value: JSON.parse(element.dataset.reportsChartCurrentDataValue), configurable: true, writable: true });
    Object.defineProperty(controller, 'previousDataValue', { value: JSON.parse(element.dataset.reportsChartPreviousDataValue), configurable: true, writable: true });
    Object.defineProperty(controller, 'typeValue', { value: element.dataset.reportsChartTypeValue, configurable: true, writable: true });
    Object.defineProperty(controller, 'chartHeightValue', { value: parseInt(element.dataset.reportsChartChartHeightValue, 10), configurable: true, writable: true });
    
    await controller.initializeChart();
  });

  it('creates a canvas and instantiates a chart', () => {
    const canvas = element.querySelector('canvas');
    expect(canvas).not.toBeNull();
    expect(window.Chart).toHaveBeenCalledTimes(1);
  });

  it('destroys the chart instance on disconnect', () => {
    controller.disconnect();
    expect(mockChartInstance.destroy).toHaveBeenCalledTimes(1);
  });

  it('updates the chart when data values change', () => {
    mockChartInstance.update.mockClear();
    
    controller.currentDataValue = { Submitted: 15, Draft: 7 };
    controller.currentDataValueChanged();

    expect(mockChartInstance.update).toHaveBeenCalledWith('none');
    expect(controller.chartInstance.data.datasets[0].data).toEqual([15, 7]);
  });
});
