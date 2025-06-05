/**
 * Centralized Chart.js configuration service
 * Provides consistent defaults and theming across all charts
 */
export class ChartConfigService {
  constructor() {
    this.theme = {
      colors: {
        primary: 'rgba(79, 70, 229, 0.8)',
        primaryBorder: 'rgba(79, 70, 229, 1)',
        secondary: 'rgba(156, 163, 175, 0.8)',
        secondaryBorder: 'rgba(156, 163, 175, 1)',
        success: 'rgba(34, 197, 94, 0.8)',
        danger: 'rgba(239, 68, 68, 0.8)',
        warning: 'rgba(245, 158, 11, 0.8)'
      },
      fonts: {
        base: 14,
        title: 16,
        small: 12
      }
    }
  }

  /**
   * Get base configuration for all charts
   */
  getBaseConfig() {
    return {
      responsive: true,
      maintainAspectRatio: false,
      animation: {
        duration: 800,
        easing: 'easeOutQuart'
      },
      plugins: {
        title: {
          display: false,
          font: { 
            size: this.theme.fonts.title,
            weight: 'bold'
          }
        },
        legend: {
          display: true,
          position: 'top',
          labels: {
            font: { size: this.theme.fonts.base },
            usePointStyle: true,
            padding: 15
          }
        },
        tooltip: {
          backgroundColor: 'rgba(0, 0, 0, 0.8)',
          titleFont: { 
            size: this.theme.fonts.title,
            weight: 'bold'
          },
          bodyFont: { size: this.theme.fonts.base },
          padding: 12,
          cornerRadius: 6,
          displayColors: true
        }
      },
      interaction: {
        mode: 'index',
        intersect: false,
        includeInvisible: true
      }
    }
  }

  /**
   * Get configuration for specific chart type
   */
  getConfigForType(type, customOptions = {}) {
    const baseConfig = this.getBaseConfig()
    const typeConfig = this.getTypeSpecificConfig(type)
    
    return this.deepMerge(baseConfig, typeConfig, customOptions)
  }

  /**
   * Get type-specific configurations
   */
  getTypeSpecificConfig(type) {
    const configs = {
      bar: {
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              font: { size: this.theme.fonts.base },
              callback: this.formatters.currency
            },
            title: {
              display: true,
              text: 'Amount (USD)',
              font: { 
                size: this.theme.fonts.title,
                weight: 'bold'
              }
            }
          },
          x: {
            ticks: {
              font: { size: this.theme.fonts.base },
              maxRotation: 45,
              minRotation: 0
            }
          }
        }
      },
      
      line: {
        elements: {
          line: {
            tension: 0.4,
            borderWidth: 3
          },
          point: {
            radius: 4,
            hoverRadius: 6
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              font: { size: this.theme.fonts.base }
            }
          },
          x: {
            ticks: {
              font: { size: this.theme.fonts.base }
            }
          }
        }
      },
      
      pie: {
        plugins: {
          legend: {
            position: 'right'
          }
        }
      },
      
      doughnut: {
        plugins: {
          legend: {
            position: 'right'
          }
        },
        cutout: '60%'
      },
      
      radar: {
        scales: {
          r: {
            beginAtZero: true,
            ticks: {
              font: { size: this.theme.fonts.small }
            }
          }
        }
      }
    }
    
    return configs[type] || {}
  }

  /**
   * Create dataset configuration
   */
  createDataset(label, data, options = {}) {
    const defaults = {
      label,
      data,
      backgroundColor: this.theme.colors.primary,
      borderColor: this.theme.colors.primaryBorder,
      borderWidth: 2
    }
    
    return { ...defaults, ...options }
  }

  /**
   * Create multiple datasets with automatic color assignment
   */
  createDatasets(datasets) {
    const colorKeys = Object.keys(this.theme.colors)
    
    return datasets.map((dataset, index) => {
      const colorKey = colorKeys[index % colorKeys.length]
      
      return this.createDataset(dataset.label, dataset.data, {
        backgroundColor: this.theme.colors[colorKey],
        borderColor: this.theme.colors[`${colorKey}Border`] || this.theme.colors[colorKey],
        ...dataset.options
      })
    })
  }

  /**
   * Common formatters
   */
  formatters = {
    currency: (value) => '$' + value.toLocaleString(),
    percentage: (value) => value + '%',
    compact: (value) => {
      if (value >= 1000000) {
        return '$' + (value / 1000000).toFixed(1) + 'M'
      } else if (value >= 1000) {
        return '$' + (value / 1000).toFixed(1) + 'K'
      }
      return '$' + value
    }
  }

  /**
   * Deep merge configuration objects
   */
  deepMerge(...objects) {
    const result = {}
    
    objects.forEach(obj => {
      Object.keys(obj || {}).forEach(key => {
        if (obj[key] && typeof obj[key] === 'object' && !Array.isArray(obj[key])) {
          result[key] = this.deepMerge(result[key] || {}, obj[key])
        } else {
          result[key] = obj[key]
        }
      })
    })
    
    return result
  }

  /**
   * Get configuration for compact mode
   */
  getCompactConfig() {
    return {
      plugins: {
        title: { display: false },
        legend: { display: false }
      },
      scales: {
        y: {
          ticks: {
            font: { size: this.theme.fonts.small },
            maxTicksLimit: 5
          }
        },
        x: {
          ticks: {
            font: { size: this.theme.fonts.small },
            maxTicksLimit: 8
          }
        }
      }
    }
  }

  /**
   * Configure Chart.js global defaults
   */
  configureGlobalDefaults(Chart) {
    if (!Chart) return

    // Set global defaults
    Chart.defaults.font.family = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'
    Chart.defaults.color = '#374151'
    
    // Disable animations in test environment
    if (process.env.NODE_ENV === 'test') {
      Chart.defaults.animation = false
    }
    
    // Add performance optimizations
    Chart.defaults.parsing = false
    Chart.defaults.normalized = true
  }
}

// Export singleton instance
export const chartConfig = new ChartConfigService() 