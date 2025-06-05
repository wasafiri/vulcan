/**
 * Mixin for safe target access with logging
 * Reduces repetitive hasXTarget checks and provides consistent error handling
 */
export const TargetSafety = {
  /**
   * Safely access a target with optional warning
   * @param {string} targetName The target name (e.g., 'submitButton')
   * @param {boolean} warn Whether to log warning if missing
   * @returns {HTMLElement|null}
   */
  safeTarget(targetName, warn = true) {
    const hasMethod = `has${targetName.charAt(0).toUpperCase()}${targetName.slice(1)}Target`
    const targetMethod = `${targetName}Target`
    
    if (this[hasMethod] && this[targetMethod]) {
      return this[targetMethod]
    }
    
    if (warn && process.env.NODE_ENV !== 'production') {
      console.warn(`${this.identifier}: Missing ${targetName} target - check HTML structure`)
    }
    
    return null
  },

  /**
   * Safely access multiple targets
   * @param {string} targetName The target name
   * @param {boolean} warn Whether to log warning if missing
   * @returns {HTMLElement[]}
   */
  safeTargets(targetName, warn = true) {
    const hasMethod = `has${targetName.charAt(0).toUpperCase()}${targetName.slice(1)}Target`
    const targetsMethod = `${targetName}Targets`
    
    if (this[hasMethod] && this[targetsMethod]) {
      return this[targetsMethod]
    }
    
    if (warn && process.env.NODE_ENV !== 'production') {
      console.warn(`${this.identifier}: Missing ${targetName} targets - check HTML structure`)
    }
    
    return []
  },

  /**
   * Execute a function only if target exists
   * @param {string} targetName The target name
   * @param {Function} fn Function to execute with target
   * @param {*} defaultValue Value to return if target missing
   */
  withTarget(targetName, fn, defaultValue = undefined) {
    const target = this.safeTarget(targetName, false)
    return target ? fn.call(this, target) : defaultValue
  },

  /**
   * Execute a function for each target
   * @param {string} targetName The target name
   * @param {Function} fn Function to execute for each target
   */
  withTargets(targetName, fn) {
    const targets = this.safeTargets(targetName, false)
    targets.forEach(target => fn.call(this, target))
  },

  /**
   * Check if all required targets exist
   * @param {string[]} targetNames Array of required target names
   * @returns {boolean}
   */
  hasRequiredTargets(...targetNames) {
    const missing = targetNames.filter(name => {
      const hasMethod = `has${name.charAt(0).toUpperCase()}${name.slice(1)}Target`
      return !this[hasMethod]
    })
    
    if (missing.length > 0 && process.env.NODE_ENV !== 'production') {
      console.error(`${this.identifier}: Missing required targets:`, missing)
    }
    
    return missing.length === 0
  }
}

/**
 * Apply mixin to a controller class
 */
export function applyTargetSafety(controllerClass) {
  Object.assign(controllerClass.prototype, TargetSafety)
  return controllerClass
} 