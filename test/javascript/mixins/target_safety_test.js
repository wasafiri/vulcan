import { applyTargetSafety } from '../../../app/javascript/mixins/target_safety'

// Create a mock controller class for testing
class MockController {
  constructor() {
    this.identifier = 'test-controller'
    this.testTarget = document.createElement('div')
    this.testTargets = [this.testTarget]
    this.hasTestTarget = true
    this.hasTestTargets = true
    
    this.anotherTarget = document.createElement('span')
    this.anotherTargets = [this.anotherTarget]
    this.hasAnotherTarget = true
    this.hasAnotherTargets = true
    
    this.singleTargets = [document.createElement('p')]
    this.hasSingleTargets = true
    this.hasSingleTarget = true
  }
}

describe('Target Safety Mixin', () => {
  let controller
  let warnSpy
  let errorSpy

  beforeEach(() => {
    // Set NODE_ENV to development for consistent behavior
    process.env.NODE_ENV = 'development'
    
    // Create spies before creating controller
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {})
    errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
    
    controller = new MockController()
    applyTargetSafety(MockController)
  })

  afterEach(() => {
    // Restore all console methods and clear mock state
    jest.restoreAllMocks()
  })

  describe('safeTarget', () => {
    it('returns target when it exists', () => {
      const target = controller.safeTarget('test')
      
      expect(target).toBe(controller.testTarget)
    })

    it('returns null when target does not exist', () => {
      const target = controller.safeTarget('missing')
      
      expect(target).toBe(null)
    })

    it('does not log warning when warn is false', () => {
      warnSpy.mockClear() // Clear any previous calls
      
      controller.safeTarget('missing', false)
      
      expect(warnSpy).not.toHaveBeenCalled()
    })

    it('does not log warning in production', () => {
      const originalEnv = process.env.NODE_ENV
      process.env.NODE_ENV = 'production'
      
      warnSpy.mockClear() // Clear any previous calls
      
      controller.safeTarget('missing')
      
      expect(warnSpy).not.toHaveBeenCalled()
      
      process.env.NODE_ENV = originalEnv
    })
  })

  describe('safeTargets', () => {
    it('returns targets when they exist', () => {
      const targets = controller.safeTargets('test')
      
      expect(targets).toBe(controller.testTargets)
    })

    it('returns empty array when targets do not exist', () => {
      const targets = controller.safeTargets('missing')
      
      expect(targets).toEqual([])
    })

    it('does not log warning when warn is false', () => {
      warnSpy.mockClear() // Clear any previous calls
      
      controller.safeTargets('missing', false)
      
      expect(warnSpy).not.toHaveBeenCalled()
    })
  })

  describe('withTarget', () => {
    it('calls function when target exists', () => {
      const mockFn = jest.fn().mockReturnValue('result')
      
      const result = controller.withTarget('test', mockFn)
      
      expect(mockFn).toHaveBeenCalledWith(controller.testTarget)
      expect(result).toBe('result')
    })

    it('returns default value when target does not exist', () => {
      const mockFn = jest.fn()
      
      const result = controller.withTarget('missing', mockFn, 'default')
      
      expect(mockFn).not.toHaveBeenCalled()
      expect(result).toBe('default')
    })

    it('returns undefined when target does not exist and no default', () => {
      const mockFn = jest.fn()
      
      const result = controller.withTarget('missing', mockFn)
      
      expect(mockFn).not.toHaveBeenCalled()
      expect(result).toBe(undefined)
    })
  })

  describe('withTargets', () => {
    it('calls function for each target when targets exist', () => {
      const mockFn = jest.fn()
      
      controller.withTargets('test', mockFn)
      
      expect(mockFn).toHaveBeenCalledTimes(1)
      expect(mockFn).toHaveBeenCalledWith(controller.testTargets[0])
    })

    it('does not call function when targets do not exist', () => {
      const mockFn = jest.fn()
      
      controller.withTargets('missing', mockFn)
      
      expect(mockFn).not.toHaveBeenCalled()
    })

    it('calls function for each target in small array', () => {
      const mockFn = jest.fn()
      
      controller.withTargets('single', mockFn)
      
      expect(mockFn).toHaveBeenCalledTimes(1)
      expect(mockFn).toHaveBeenCalledWith(controller.singleTargets[0])
    })
  })

  describe('hasRequiredTargets', () => {
    it('returns true when all targets exist', () => {
      const result = controller.hasRequiredTargets('test', 'another')
      
      expect(result).toBe(true)
    })

    it('returns false when some targets are missing', () => {
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
      
      const result = controller.hasRequiredTargets('test', 'missing')
      
      expect(result).toBe(false)
      expect(errorSpy).toHaveBeenCalledWith(
        'test-controller: Missing required targets:',
        ['missing']
      )
    })

    it('returns false when all targets are missing', () => {
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
      
      const result = controller.hasRequiredTargets('missing', 'alsoMissing')
      
      expect(result).toBe(false)
      expect(errorSpy).toHaveBeenCalledWith(
        'test-controller: Missing required targets:',
        ['missing', 'alsoMissing']
      )
    })
  })

  describe('mixin application', () => {
    it('adds target safety methods to controller', () => {
      expect(typeof controller.safeTarget).toBe('function')
      expect(typeof controller.safeTargets).toBe('function')
      expect(typeof controller.withTarget).toBe('function')
      expect(typeof controller.withTargets).toBe('function')
      expect(typeof controller.hasRequiredTargets).toBe('function')
    })

    it('overwrites existing methods when applied', () => {
      class TestController {
        constructor() {
          this.identifier = 'test'
        }
        
        safeTarget(targetName) {
          return 'original'
        }
      }
      
      const instance = new TestController()
      
      // Check that the original method works before applying mixin
      expect(instance.safeTarget('test')).toBe('original')
      
      // Apply mixin - it will overwrite existing methods
      applyTargetSafety(TestController)
      
      // The mixin method should now be used (returns null since no targets exist)
      expect(instance.safeTarget('test')).toBe(null)
    })
  })
})

// Separate test suite for production environment to ensure complete isolation
describe('Target Safety Mixin - Production Environment', () => {
  let originalEnv

  beforeAll(() => {
    originalEnv = process.env.NODE_ENV
    process.env.NODE_ENV = 'production'
  })

  afterAll(() => {
    process.env.NODE_ENV = originalEnv
  })

  beforeEach(() => {
    // Clear all mocks before each test
    jest.clearAllMocks()
  })

  it('does not log error in production', () => {
    // Create a completely fresh controller for this test
    class ProductionController {
      constructor() {
        this.identifier = 'production-controller'
      }
    }
    
    // Apply mixin to the fresh controller
    applyTargetSafety(ProductionController)
    const instance = new ProductionController()
    
    // Create spy after setting up the controller
    const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => {})
    
    const result = instance.hasRequiredTargets('missing')
    
    expect(result).toBe(false)
    expect(errorSpy).not.toHaveBeenCalled()
    
    errorSpy.mockRestore()
  })
}) 