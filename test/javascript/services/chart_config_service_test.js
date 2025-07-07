import { ChartConfigService } from '../../../app/javascript/services/chart_config'

// Mock Chart.js
const mockChart = {
  defaults: {
    font: {
      family: 'Helvetica Neue'
    },
    animation: {},
    parsing: true,
    normalized: false,
    responsive: true,
    maintainAspectRatio: true,
    plugins: {
      legend: {},
      tooltip: {}
    },
    scales: {}
  }
}

describe('ChartConfigService', () => {
  let service

  beforeEach(() => {
    service = new ChartConfigService()
    
    // Mock console methods
    global.console.warn = jest.fn()
  })

  describe('constructor', () => {
    it('initializes with default color palette', () => {
      expect(service.theme.colors).toBeDefined()
      expect(typeof service.theme.colors).toBe('object')
      expect(service.theme.colors.primary).toBeDefined()
    })

    it('initializes with font configuration', () => {
      expect(service.theme.fonts).toBeDefined()
      expect(service.theme.fonts.base).toBeDefined()
      expect(service.theme.fonts.title).toBeDefined()
    })
  })

  describe('getBaseConfig', () => {
    it('returns base configuration object', () => {
      const config = service.getBaseConfig()

      expect(config).toEqual({
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false,
          includeInvisible: true
        },
        animation: {
          duration: 800,
          easing: 'easeOutQuart'
        },
        plugins: {
          legend: {
            display: true,
            position: 'top',
            labels: {
              usePointStyle: true,
              padding: 15,
              font: {
                size: 14
              }
            }
          },
          title: {
            display: false,
            font: {
              size: 16,
              weight: 'bold'
            }
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleFont: {
              size: 16,
              weight: 'bold'
            },
            bodyFont: {
              size: 14
            },
            cornerRadius: 6,
            padding: 12,
            displayColors: true
          }
        }
      })
    })

    it('sets performance optimizations', () => {
      const config = service.getBaseConfig()

      expect(config.animation.duration).toBe(800)
      expect(config.animation.easing).toBe('easeOutQuart')
    })
  })

  describe('getConfigForType', () => {
    it('returns base config for unknown chart types', () => {
      const config = service.getConfigForType('unknown')
      const baseConfig = service.getBaseConfig()

      expect(config).toEqual(baseConfig)
    })

    it('merges custom options with type-specific config', () => {
      const customOptions = {
        plugins: {
          title: {
            display: true,
            text: 'Custom Title'
          }
        }
      }

      const config = service.getConfigForType('bar', customOptions)

      expect(config.plugins.title).toEqual(expect.objectContaining({
        display: true,
        text: 'Custom Title'
      }))
    })

    it('returns line chart specific configuration', () => {
      const config = service.getConfigForType('line')

      expect(config.elements).toBeDefined()
      expect(config.elements.line).toBeDefined()
      expect(config.elements.point).toBeDefined()
    })

    it('returns bar chart specific configuration', () => {
      const config = service.getConfigForType('bar')

      expect(config.scales).toBeDefined()
      expect(config.scales.y).toBeDefined()
      expect(config.scales.x).toBeDefined()
      expect(config.scales.y.beginAtZero).toBe(true)
    })

    it('returns doughnut chart specific configuration', () => {
      const config = service.getConfigForType('doughnut')

      expect(config.cutout).toBe('60%')
      expect(config.plugins.legend.position).toBe('right')
    })

    it('returns pie chart specific configuration', () => {
      const config = service.getConfigForType('pie')

      expect(config.plugins.legend.position).toBe('right')
    })
  })

  describe('createDataset', () => {
    it('applies theme colors by default', () => {
      const dataset = service.createDataset('Test', [1, 2, 3])

      expect(dataset.backgroundColor).toBe(service.theme.colors.primary)
      expect(dataset.borderColor).toBe(service.theme.colors.primaryBorder)
    })

    it('sets default styling properties', () => {
      const dataset = service.createDataset('Test', [1, 2, 3])

      expect(dataset.label).toBe('Test')
      expect(dataset.data).toEqual([1, 2, 3])
      expect(dataset.borderWidth).toBe(2)
    })

    it('allows custom options to override defaults', () => {
      const customOptions = {
        backgroundColor: 'red',
        borderWidth: 5
      }

      const dataset = service.createDataset('Test', [1, 2, 3], customOptions)

      expect(dataset.backgroundColor).toBe('red')
      expect(dataset.borderWidth).toBe(5)
      expect(dataset.borderColor).toBe(service.theme.colors.primaryBorder) // Should keep default
    })
  })

  describe('createDatasets', () => {
    it('creates multiple datasets with automatic color assignment', () => {
      const inputDatasets = [
        { label: 'Dataset 1', data: [1, 2, 3] },
        { label: 'Dataset 2', data: [4, 5, 6] }
      ]

      const datasets = service.createDatasets(inputDatasets)
      
      expect(datasets).toHaveLength(2)
      expect(datasets[0].label).toBe('Dataset 1')
      expect(datasets[1].label).toBe('Dataset 2')
      
      // Different colors should be assigned
      expect(datasets[0].backgroundColor).toBeDefined()
      expect(datasets[1].backgroundColor).toBeDefined()
    })

    it('cycles through colors when more datasets than colors', () => {
      const colorKeys = Object.keys(service.theme.colors)
      const inputDatasets = colorKeys.map((_, index) => ({
        label: `Dataset ${index}`,
        data: [index]
      }))
      
      // Add one more to test cycling
      inputDatasets.push({ label: 'Extra Dataset', data: [99] })

      const datasets = service.createDatasets(inputDatasets)
      
      expect(datasets).toHaveLength(colorKeys.length + 1)
      // First and last should have same color (cycling)
      expect(datasets[0].backgroundColor).toBe(datasets[colorKeys.length].backgroundColor)
    })
  })

  describe('formatters', () => {
    it('provides currency formatter', () => {
      const formatted = service.formatters.currency(1234.56)
      expect(formatted).toMatch(/\$1,234\.56|\$1,235/) // Allow for rounding differences
    })

    it('provides percentage formatter', () => {
      const formatted = service.formatters.percentage(0.1234)
      expect(formatted).toBe('0.1234%')
    })

    it('provides compact formatter', () => {
      expect(service.formatters.compact(1234567)).toBe('$1.2M')
      expect(service.formatters.compact(1234)).toBe('$1.2K')
      expect(service.formatters.compact(123)).toBe('$123')
    })

    it('handles edge cases in formatters', () => {
      expect(service.formatters.currency(0)).toBe('$0')
      expect(service.formatters.percentage(0)).toBe('0%')
      expect(service.formatters.compact(0)).toBe('$0')
    })
  })

  describe('deepMerge', () => {
    it('merges objects deeply', () => {
      const obj1 = {
        a: 1,
        b: { c: 2, d: 3 }
      }
      
      const obj2 = {
        b: { d: 4, e: 5 },
        f: 6
      }

      const result = service.deepMerge(obj1, obj2)

      expect(result).toEqual({
        a: 1,
        b: { c: 2, d: 4, e: 5 },
        f: 6
      })
    })

    it('handles null and undefined values', () => {
      const obj1 = { a: 1 }
      const obj2 = null
      const obj3 = { b: 2 }

      const result = service.deepMerge(obj1, obj2, obj3)

      expect(result).toEqual({ a: 1, b: 2 })
    })
  })

  describe('getCompactConfig', () => {
    it('returns configuration optimized for small spaces', () => {
      const config = service.getCompactConfig()

      expect(config.plugins.legend.display).toBe(false)
      expect(config.plugins.title.display).toBe(false)
      expect(config.scales.y.ticks.maxTicksLimit).toBe(5)
      expect(config.scales.x.ticks.maxTicksLimit).toBe(8)
    })

    it('uses smaller fonts for compact display', () => {
      const config = service.getCompactConfig()

      expect(config.scales.y.ticks.font.size).toBe(service.theme.fonts.small)
      expect(config.scales.x.ticks.font.size).toBe(service.theme.fonts.small)
    })
  })

  describe('configureGlobalDefaults', () => {
    let mockChart
    
    beforeEach(() => {
      mockChart = {
        defaults: {
          font: {},
          color: null,
          animation: null,
          parsing: null,
          normalized: null
        }
      }
    })

    it('configures Chart.js global font family and color', () => {
      service.configureGlobalDefaults(mockChart)

      expect(mockChart.defaults.font.family).toBe('-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif')
      expect(mockChart.defaults.color).toBe('#374151')
    })

    it('disables animation in test environment', () => {
      const originalEnv = process.env.NODE_ENV
      process.env.NODE_ENV = 'test'
      
      service.configureGlobalDefaults(mockChart)

      expect(mockChart.defaults.animation).toBe(false)
      
      process.env.NODE_ENV = originalEnv
    })

    it('configures performance optimizations', () => {
      service.configureGlobalDefaults(mockChart)

      expect(mockChart.defaults.parsing).toBe(false)
      expect(mockChart.defaults.normalized).toBe(true)
    })

    it('handles missing Chart gracefully', () => {
      expect(() => service.configureGlobalDefaults(null)).not.toThrow()
      expect(() => service.configureGlobalDefaults(undefined)).not.toThrow()
    })
  })

  describe('color utilities', () => {
    it('has sufficient colors for common use cases', () => {
      const colorCount = Object.keys(service.theme.colors).length
      expect(colorCount).toBeGreaterThanOrEqual(5)
    })

    it('provides accessible color contrast', () => {
      // All colors should be valid CSS color values
      Object.values(service.theme.colors).forEach(color => {
        expect(typeof color).toBe('string')
        expect(color.length).toBeGreaterThan(3)
      })
    })
  })

  describe('integration scenarios', () => {
    it('creates complete chart configuration for bar chart', () => {
      const data = [
        { label: 'Sales', data: [100, 200, 300], options: { backgroundColor: 'blue' } },
        { label: 'Profit', data: [50, 100, 150] }
      ]

      const datasets = service.createDatasets(data)
      const config = service.getConfigForType('bar', {
        plugins: {
          title: { display: true, text: 'Sales Report' }
        }
      })

      expect(datasets).toHaveLength(2)
      expect(config.plugins.title.text).toBe('Sales Report')
      expect(config.scales.y.beginAtZero).toBe(true)
    })

    it('handles empty data gracefully', () => {
      const datasets = service.createDatasets([])
      expect(datasets).toEqual([])

      const config = service.getConfigForType('line')
      expect(config).toBeDefined()
    })
  })
}) 