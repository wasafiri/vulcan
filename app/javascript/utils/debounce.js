/**
 * Debounce Utility
 *
 * Provides simple leading/trailing edge debouncing with cancel, flush, and pending support.
 */
export function debounce(func, wait = 0, options = {}) {
  if (typeof func !== 'function') {
    throw new TypeError('Expected a function')
  }

  // If the caller explicitly set `trailing`, use that.
  // Otherwise, default `trailing` to the inverse of `leading`.
  const leading  = options.leading === true
  const trailing = Object.prototype.hasOwnProperty.call(options, 'trailing')
    ? options.trailing
    : !leading

  let timeoutId = null
  let lastArgs, lastThis, result

  function debounced(...args) {
    lastArgs = args
    lastThis = this

    const callNow = leading && timeoutId === null

    // Clear any existing timer.
    if (timeoutId !== null) {
      clearTimeout(timeoutId)
      timeoutId = null
    }

    // Leading edge
    if (callNow) {
      result = func.apply(lastThis, lastArgs)
    }

    // Trailing edge
    if (trailing) {
      timeoutId = setTimeout(() => {
        timeoutId = null
        result = func.apply(lastThis, lastArgs)
      }, wait)
    }

    return result
  }

  debounced.cancel = function() {
    if (timeoutId !== null) {
      clearTimeout(timeoutId)
      timeoutId = null
    }
  }

  debounced.flush = function() {
    if (timeoutId === null) {
      return undefined
    }
    clearTimeout(timeoutId)
    timeoutId = null
    result = func.apply(lastThis, lastArgs)
    return result
  }

  debounced.pending = function() {
    return timeoutId !== null
  }

  return debounced
}

// Pre-configured delay values
export const DEBOUNCE_DELAYS = {
  SEARCH:      250,
  FORM_CHANGE:  20,
  UI_UPDATE:    50,
  VERY_SHORT:   10
}

// Convenience creators
export function createSearchDebounce(func)       { return debounce(func, DEBOUNCE_DELAYS.SEARCH) }
export function createFormChangeDebounce(func)   { return debounce(func, DEBOUNCE_DELAYS.FORM_CHANGE) }
export function createUIUpdateDebounce(func)     { return debounce(func, DEBOUNCE_DELAYS.UI_UPDATE) }
export function createVeryShortDebounce(func)    { return debounce(func, DEBOUNCE_DELAYS.VERY_SHORT) }
export function simpleDebounce(func, wait)        { return debounce(func, wait, { leading: false, trailing: true }) }
export function throttle(func, wait)              { return debounce(func, wait, { leading: true, trailing: true, maxWait: wait }) }
