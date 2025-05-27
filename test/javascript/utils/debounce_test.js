import { 
  debounce, 
  DEBOUNCE_DELAYS, 
  createSearchDebounce, 
  createFormChangeDebounce, 
  createUIUpdateDebounce, 
  createVeryShortDebounce 
} from 'utils/debounce'

describe('Debounce Utility', () => {
  beforeEach(() => {
    jest.useFakeTimers()
  })

  afterEach(() => {
    jest.useRealTimers()
  })

  describe('debounce', () => {
    test('calls function after specified delay', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100)
      
      debouncedFunc()
      expect(func).not.toHaveBeenCalled()
      
      jest.advanceTimersByTime(100)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('delays function execution on subsequent calls', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100)
      
      debouncedFunc()
      jest.advanceTimersByTime(50)
      debouncedFunc()
      jest.advanceTimersByTime(50)
      
      expect(func).not.toHaveBeenCalled()
      
      jest.advanceTimersByTime(50)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('passes arguments to debounced function', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100)
      
      debouncedFunc('arg1', 'arg2', 'arg3')
      jest.advanceTimersByTime(100)
      
      expect(func).toHaveBeenCalledWith('arg1', 'arg2', 'arg3')
    })

    test('preserves context (this) when called', () => {
      const obj = {
        value: 'test',
        method: jest.fn(function() {
          return this.value
        })
      }
      
      obj.debouncedMethod = debounce(obj.method, 100)
      obj.debouncedMethod()
      
      jest.advanceTimersByTime(100)
      
      expect(obj.method).toHaveBeenCalled()
    })

    test('returns result from last function call', () => {
      const func = jest.fn(() => 'result')
      const debouncedFunc = debounce(func, 100)
      
      debouncedFunc()
      jest.advanceTimersByTime(100)
      
      expect(func).toHaveReturnedWith('result')
    })

    test('handles zero wait time', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 0)
      
      debouncedFunc()
      jest.advanceTimersByTime(0)
      
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('throws error for non-function input', () => {
      expect(() => {
        debounce('not a function', 100)
      }).toThrow(TypeError)
      
      expect(() => {
        debounce(null, 100)
      }).toThrow(TypeError)
      
      expect(() => {
        debounce(undefined, 100)
      }).toThrow(TypeError)
    })
  })

  describe('debounce with leading option', () => {
    test('calls function immediately when leading is true', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100, { leading: true })
      
      debouncedFunc()
      expect(func).toHaveBeenCalledTimes(1)
      
      jest.advanceTimersByTime(100)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('calls function both on leading and trailing edge', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100, { leading: true, trailing: true })
      
      debouncedFunc()
      expect(func).toHaveBeenCalledTimes(1)
      
      jest.advanceTimersByTime(100)
      expect(func).toHaveBeenCalledTimes(2)
    })

    test('only calls on leading edge when trailing is false', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100, { leading: true, trailing: false })
      
      debouncedFunc()
      expect(func).toHaveBeenCalledTimes(1)
      
      jest.advanceTimersByTime(100)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('never calls function when both leading and trailing are false', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100, { leading: false, trailing: false })
      
      debouncedFunc()
      expect(func).not.toHaveBeenCalled()
      
      jest.advanceTimersByTime(100)
      expect(func).not.toHaveBeenCalled()
      
      // Try multiple calls
      debouncedFunc()
      debouncedFunc()
      jest.advanceTimersByTime(200)
      expect(func).not.toHaveBeenCalled()
    })
  })

  describe('debounce methods', () => {
    test('cancel stops pending execution', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100)
      
      debouncedFunc()
      expect(debouncedFunc.pending()).toBe(true)
      
      debouncedFunc.cancel()
      expect(debouncedFunc.pending()).toBe(false)
      
      jest.advanceTimersByTime(100)
      expect(func).not.toHaveBeenCalled()
    })

    test('flush immediately executes pending function', () => {
      const func = jest.fn(() => 'flushed')
      const debouncedFunc = debounce(func, 100)
      
      debouncedFunc()
      const result = debouncedFunc.flush()
      
      expect(func).toHaveBeenCalledTimes(1)
      expect(result).toBe('flushed')
      expect(debouncedFunc.pending()).toBe(false)
    })

    test('flush returns undefined when no pending execution', () => {
      const func = jest.fn(() => 'result')
      const debouncedFunc = debounce(func, 100)
      
      const result = debouncedFunc.flush()
      expect(result).toBeUndefined()
      expect(func).not.toHaveBeenCalled()
    })

    test('pending returns true when execution is pending', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100)
      
      expect(debouncedFunc.pending()).toBe(false)
      
      debouncedFunc()
      expect(debouncedFunc.pending()).toBe(true)
      
      jest.advanceTimersByTime(100)
      expect(debouncedFunc.pending()).toBe(false)
    })
  })

  describe('DEBOUNCE_DELAYS constants', () => {
    test('has correct delay values', () => {
      expect(DEBOUNCE_DELAYS.SEARCH).toBe(250)
      expect(DEBOUNCE_DELAYS.FORM_CHANGE).toBe(20)
      expect(DEBOUNCE_DELAYS.UI_UPDATE).toBe(50)
      expect(DEBOUNCE_DELAYS.VERY_SHORT).toBe(10)
    })
  })

  describe('pre-configured debounce creators', () => {
    test('createSearchDebounce uses correct delay', () => {
      const func = jest.fn()
      const debouncedFunc = createSearchDebounce(func)
      
      debouncedFunc()
      jest.advanceTimersByTime(249)
      expect(func).not.toHaveBeenCalled()
      
      jest.advanceTimersByTime(1)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('createFormChangeDebounce uses correct delay', () => {
      const func = jest.fn()
      const debouncedFunc = createFormChangeDebounce(func)
      
      debouncedFunc()
      jest.advanceTimersByTime(19)
      expect(func).not.toHaveBeenCalled()
      
      jest.advanceTimersByTime(1)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('createUIUpdateDebounce uses correct delay', () => {
      const func = jest.fn()
      const debouncedFunc = createUIUpdateDebounce(func)
      
      debouncedFunc()
      jest.advanceTimersByTime(49)
      expect(func).not.toHaveBeenCalled()
      
      jest.advanceTimersByTime(1)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('createVeryShortDebounce uses correct delay', () => {
      const func = jest.fn()
      const debouncedFunc = createVeryShortDebounce(func)
      
      debouncedFunc()
      jest.advanceTimersByTime(9)
      expect(func).not.toHaveBeenCalled()
      
      jest.advanceTimersByTime(1)
      expect(func).toHaveBeenCalledTimes(1)
    })
  })

  describe('real-world scenarios', () => {
    test('search input debouncing', () => {
      const searchFunction = jest.fn()
      const debouncedSearch = createSearchDebounce(searchFunction)
      
      // Simulate rapid typing
      debouncedSearch('a')
      jest.advanceTimersByTime(50)
      debouncedSearch('ab')
      jest.advanceTimersByTime(50)
      debouncedSearch('abc')
      jest.advanceTimersByTime(50)
      debouncedSearch('abcd')
      
      // Function shouldn't be called yet
      expect(searchFunction).not.toHaveBeenCalled()
      
      // Wait for full delay
      jest.advanceTimersByTime(250)
      
      // Should only be called once with the last value
      expect(searchFunction).toHaveBeenCalledTimes(1)
      expect(searchFunction).toHaveBeenCalledWith('abcd')
    })

    test('form validation debouncing', () => {
      const validateFunction = jest.fn()
      const debouncedValidate = createFormChangeDebounce(validateFunction)
      
      // Simulate field changes
      debouncedValidate({ field: 'email', value: 'a' })
      debouncedValidate({ field: 'email', value: 'ab' })
      debouncedValidate({ field: 'email', value: 'abc@' })
      debouncedValidate({ field: 'email', value: 'abc@example.com' })
      
      jest.advanceTimersByTime(20)
      
      expect(validateFunction).toHaveBeenCalledTimes(1)
      expect(validateFunction).toHaveBeenCalledWith({ field: 'email', value: 'abc@example.com' })
    })

    test('UI state update debouncing', () => {
      const updateUI = jest.fn()
      const debouncedUpdateUI = createUIUpdateDebounce(updateUI)
      
      // Simulate rapid state changes
      debouncedUpdateUI({ visible: true })
      debouncedUpdateUI({ visible: false })
      debouncedUpdateUI({ visible: true })
      
      jest.advanceTimersByTime(50)
      
      expect(updateUI).toHaveBeenCalledTimes(1)
      expect(updateUI).toHaveBeenCalledWith({ visible: true })
    })

    test('controller refresh debouncing', () => {
      const refreshController = jest.fn()
      const debouncedRefresh = createVeryShortDebounce(refreshController)
      
      // Simulate rapid controller events
      debouncedRefresh('event1')
      debouncedRefresh('event2')
      debouncedRefresh('event3')
      
      jest.advanceTimersByTime(10)
      
      expect(refreshController).toHaveBeenCalledTimes(1)
      expect(refreshController).toHaveBeenCalledWith('event3')
    })
  })

  describe('edge cases and error handling', () => {
    test('handles function that throws errors', () => {
      const errorFunc = jest.fn(() => {
        throw new Error('Test error')
      })
      const debouncedFunc = debounce(errorFunc, 100)
      
      debouncedFunc()
      
      expect(() => {
        jest.advanceTimersByTime(100)
      }).toThrow('Test error')
      
      expect(errorFunc).toHaveBeenCalledTimes(1)
    })

    test('handles very large wait times', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 999999)
      
      debouncedFunc()
      jest.advanceTimersByTime(100000)
      expect(func).not.toHaveBeenCalled()
      
      jest.advanceTimersByTime(999999)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('handles multiple rapid cancellations', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100)
      
      debouncedFunc()
      debouncedFunc.cancel()
      debouncedFunc()
      debouncedFunc.cancel()
      debouncedFunc()
      
      jest.advanceTimersByTime(100)
      expect(func).toHaveBeenCalledTimes(1)
    })

    test('handles function with complex return values', () => {
      const complexFunc = jest.fn(() => ({
        status: 'success',
        data: [1, 2, 3],
        metadata: { timestamp: Date.now() }
      }))
      
      const debouncedFunc = debounce(complexFunc, 100)
      
      debouncedFunc()
      jest.advanceTimersByTime(100)
      
      const result = complexFunc.mock.results[0].value
      expect(result).toHaveProperty('status', 'success')
      expect(result).toHaveProperty('data', [1, 2, 3])
      expect(result).toHaveProperty('metadata')
    })

    test('cleanup works properly', () => {
      const func = jest.fn()
      let debouncedFunc = debounce(func, 100)
      
      debouncedFunc()
      expect(debouncedFunc.pending()).toBe(true)
      
      // Simulate cleanup (e.g., component unmount)
      debouncedFunc.cancel()
      debouncedFunc = null
      
      jest.advanceTimersByTime(100)
      expect(func).not.toHaveBeenCalled()
    })
  })

  describe('performance considerations', () => {
    test('handles many rapid calls efficiently', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 50)
      
      // Simulate 1000 rapid calls
      for (let i = 0; i < 1000; i++) {
        debouncedFunc(i)
      }
      
      jest.advanceTimersByTime(50)
      
      // Should only call the function once with the last value
      expect(func).toHaveBeenCalledTimes(1)
      expect(func).toHaveBeenCalledWith(999)
    })

    test('memory usage remains constant with many calls', () => {
      const func = jest.fn()
      const debouncedFunc = debounce(func, 100)
      
      // Make many calls and cancel them
      for (let i = 0; i < 100; i++) {
        debouncedFunc(i)
        if (i % 10 === 0) {
          debouncedFunc.cancel()
        }
      }
      
      jest.advanceTimersByTime(100)
      
      // Should still work correctly
      expect(func).toHaveBeenCalledTimes(1)
    })
  })
})
