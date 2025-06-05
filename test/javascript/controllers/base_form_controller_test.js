import BaseFormController from '../../../app/javascript/controllers/base/form_controller'
import { railsRequest } from '../../../app/javascript/services/rails_request'
import { setVisible } from '../../../app/javascript/utils/visibility'

// Mock dependencies
jest.mock('../../../app/javascript/services/rails_request')
jest.mock('../../../app/javascript/utils/visibility')

describe('BaseFormController', () => {
  let controller
  let mockForm
  let mockSubmitButton
  let mockStatusMessage
  let mockErrorContainer
  let mockElement

  beforeEach(() => {
    // Create mock DOM elements
    mockElement = document.createElement('div')
    mockForm = document.createElement('form')
    mockForm.action = '/test/submit'
    
    mockSubmitButton = document.createElement('button')
    mockSubmitButton.type = 'submit'
    mockSubmitButton.innerHTML = 'Submit'
    
    mockStatusMessage = document.createElement('div')
    mockErrorContainer = document.createElement('div')

    // Create controller instance
    controller = new BaseFormController()
    
    // Mock the read-only properties using Object.defineProperty
    Object.defineProperty(controller, 'element', {
      value: mockElement,
      writable: false,
      configurable: true
    })
    
    Object.defineProperty(controller, 'identifier', {
      value: 'test-form',
      writable: false,
      configurable: true
    })
    
    // Mock targets
    controller.formTarget = mockForm
    controller.submitButtonTarget = mockSubmitButton
    controller.statusMessageTarget = mockStatusMessage
    controller.errorContainerTarget = mockErrorContainer
    
    // Mock target presence checks
    controller.hasFormTarget = true
    controller.hasSubmitButtonTarget = true
    controller.hasStatusMessageTarget = true
    controller.hasErrorContainerTarget = true
    
    // Mock values
    controller.urlValue = '/test/submit'
    controller.methodValue = 'post'
    controller.resetOnSuccessValue = false
    controller.redirectOnSuccessValue = true

    // Mock dispatch method
    controller.dispatch = jest.fn()

    // Clear mocks
    railsRequest.perform.mockClear()
    railsRequest.cancel.mockClear()
    setVisible.mockClear()

    // Mock successful request by default
    railsRequest.perform.mockResolvedValue({
      success: true,
      data: { message: 'Success!' }
    })
  })

  afterEach(() => {
    jest.clearAllMocks()
  })

  describe('connect', () => {
    it('initializes request key and sets up form handlers', () => {
      const setupSpy = jest.spyOn(controller, '_setupFormHandlers')
      
      controller.connect()
      
      expect(controller.requestKey).toMatch(/^form-test-form-\d+$/)
      expect(setupSpy).toHaveBeenCalled()
    })
  })

  describe('disconnect', () => {
    it('cancels pending requests and tears down handlers', () => {
      const teardownSpy = jest.spyOn(controller, '_teardownFormHandlers')
      controller.requestKey = 'test-key'
      
      controller.disconnect()
      
      expect(railsRequest.cancel).toHaveBeenCalledWith('test-key')
      expect(teardownSpy).toHaveBeenCalled()
    })
  })

  describe('submit', () => {
    beforeEach(() => {
      controller.connect()
      jest.spyOn(controller, 'collectFormData').mockReturnValue({ name: 'Test' })
      jest.spyOn(controller, 'validateBeforeSubmit').mockResolvedValue({ valid: true })
      jest.spyOn(controller, 'clearErrors').mockImplementation(() => {})
      jest.spyOn(controller, 'setLoadingState').mockImplementation(() => {})
    })

    it('prevents default event and submits form', async () => {
      const mockEvent = { preventDefault: jest.fn() }
      
      await controller.submit(mockEvent)
      
      expect(mockEvent.preventDefault).toHaveBeenCalled()
      expect(controller.clearErrors).toHaveBeenCalled()
      expect(controller.setLoadingState).toHaveBeenCalledWith(true)
      expect(railsRequest.perform).toHaveBeenCalledWith({
        method: 'post',
        url: '/test/submit',
        body: { name: 'Test' },
        key: controller.requestKey
      })
    })

    it('handles validation errors', async () => {
      const validationErrors = {
        name: ['Name is required'],
        email: ['Email is invalid']
      }
      
      controller.validateBeforeSubmit.mockResolvedValue({
        valid: false,
        errors: validationErrors
      })
      
      jest.spyOn(controller, 'handleValidationErrors').mockImplementation(() => {})
      
      await controller.submit()
      
      expect(controller.handleValidationErrors).toHaveBeenCalledWith(validationErrors)
      expect(railsRequest.perform).not.toHaveBeenCalled()
    })

    it('handles request success', async () => {
      const responseData = { message: 'Form submitted!', redirect_url: '/success' }
      railsRequest.perform.mockResolvedValue({ success: true, data: responseData })
      
      jest.spyOn(controller, 'handleSuccess').mockImplementation(() => {})
      
      await controller.submit()
      
      expect(controller.handleSuccess).toHaveBeenCalledWith(responseData)
      expect(controller.setLoadingState).toHaveBeenCalledWith(false)
    })

    it('handles request errors', async () => {
      const error = new Error('Network error')
      railsRequest.perform.mockRejectedValue(error)
      
      jest.spyOn(controller, 'handleError').mockImplementation(() => {})
      
      await controller.submit()
      
      expect(controller.handleError).toHaveBeenCalledWith(error)
      expect(controller.setLoadingState).toHaveBeenCalledWith(false)
    })
  })

  describe('collectFormData', () => {
    it('returns empty object when no form target', () => {
      controller.hasFormTarget = false
      
      const result = controller.collectFormData()
      
      expect(result).toEqual({})
    })

    it('collects form data correctly', () => {
      // Create form with inputs
      const nameInput = document.createElement('input')
      nameInput.name = 'name'
      nameInput.value = 'John Doe'
      
      const emailInput = document.createElement('input')
      emailInput.name = 'email'
      emailInput.value = 'john@example.com'
      
      mockForm.appendChild(nameInput)
      mockForm.appendChild(emailInput)
      
      const result = controller.collectFormData()
      
      expect(result).toEqual({
        name: 'John Doe',
        email: 'john@example.com'
      })
    })

    it('handles array fields correctly', () => {
      const checkbox1 = document.createElement('input')
      checkbox1.type = 'checkbox'
      checkbox1.name = 'tags[]'
      checkbox1.value = 'red'
      checkbox1.checked = true
      
      const checkbox2 = document.createElement('input')
      checkbox2.type = 'checkbox'
      checkbox2.name = 'tags[]'
      checkbox2.value = 'blue'
      checkbox2.checked = true
      
      mockForm.appendChild(checkbox1)
      mockForm.appendChild(checkbox2)
      
      const result = controller.collectFormData()
      
      expect(result.tags).toEqual(['red', 'blue'])
    })
  })

  describe('validateBeforeSubmit', () => {
    it('returns valid by default', async () => {
      const result = await controller.validateBeforeSubmit({ name: 'Test' })
      
      expect(result).toEqual({ valid: true })
    })
  })

  describe('handleSuccess', () => {
    beforeEach(() => {
      jest.spyOn(controller, 'showStatus').mockImplementation(() => {})
      
      // Mock window.location
      delete window.location
      window.location = { href: '' }
    })

    it('shows success message when provided', async () => {
      const data = { message: 'Success!' }
      
      await controller.handleSuccess(data)
      
      expect(controller.showStatus).toHaveBeenCalledWith('Success!', 'success')
    })

    it('resets form when resetOnSuccess is true', async () => {
      controller.resetOnSuccessValue = true
      mockForm.reset = jest.fn()
      
      await controller.handleSuccess({})
      
      expect(mockForm.reset).toHaveBeenCalled()
    })

    it('dispatches success event', async () => {
      const data = { message: 'Success!' }
      
      await controller.handleSuccess(data)
      
      expect(controller.dispatch).toHaveBeenCalledWith('success', { detail: data })
    })

    it('redirects when redirectOnSuccess is true and redirect_url provided', async () => {
      const data = { redirect_url: '/dashboard' }
      
      await controller.handleSuccess(data)
      
      expect(window.location.href).toBe('/dashboard')
    })
  })

  describe('handleError', () => {
    beforeEach(() => {
      jest.spyOn(controller, 'handleValidationErrors').mockImplementation(() => {})
      jest.spyOn(controller, 'showStatus').mockImplementation(() => {})
      jest.spyOn(console, 'error').mockImplementation(() => {})
    })

    it('handles validation errors from error data', () => {
      const error = {
        message: 'Validation failed',
        data: {
          errors: {
            name: ['Name is required'],
            email: ['Email is invalid']
          }
        }
      }
      
      controller.handleError(error)
      
      expect(controller.handleValidationErrors).toHaveBeenCalledWith(error.data.errors)
      expect(console.error).toHaveBeenCalledWith('Form submission error:', error)
    })

    it('shows generic error message when no validation errors', () => {
      const error = new Error('Network error')
      
      controller.handleError(error)
      
      expect(controller.showStatus).toHaveBeenCalledWith('Network error', 'error')
      expect(controller.dispatch).toHaveBeenCalledWith('error', { detail: error })
    })
  })

  describe('handleValidationErrors', () => {
    beforeEach(() => {
      jest.spyOn(controller, 'showFieldError').mockImplementation(() => {})
      jest.spyOn(controller, 'showStatus').mockImplementation(() => {})
    })

    it('shows field-specific errors and general message', () => {
      const errors = {
        name: ['Name is required'],
        email: ['Email is invalid', 'Email must be unique']
      }
      
      controller.handleValidationErrors(errors)
      
      expect(controller.showFieldError).toHaveBeenCalledWith('name', 'Name is required')
      expect(controller.showFieldError).toHaveBeenCalledWith('email', 'Email is invalid, Email must be unique')
      expect(controller.showStatus).toHaveBeenCalledWith('Please correct the errors below', 'error')
    })

    it('handles string error messages', () => {
      const errors = {
        name: 'Name is required'
      }
      
      controller.handleValidationErrors(errors)
      
      expect(controller.showFieldError).toHaveBeenCalledWith('name', 'Name is required')
    })
  })

  describe('showFieldError', () => {
    it('shows error for field and adds error styling', () => {
      const nameInput = document.createElement('input')
      nameInput.name = 'name'
      
      const fieldContainer = document.createElement('div')
      const errorElement = document.createElement('div')
      errorElement.setAttribute('data-field-error', 'name')
      
      fieldContainer.appendChild(nameInput)
      fieldContainer.appendChild(errorElement)
      mockForm.appendChild(fieldContainer)
      
      controller.showFieldError('name', 'Name is required')
      
      expect(errorElement.textContent).toBe('Name is required')
      expect(setVisible).toHaveBeenCalledWith(errorElement, true)
      expect(nameInput.classList.contains('border-red-500')).toBe(true)
    })

    it('handles array field names', () => {
      const selectInput = document.createElement('select')
      selectInput.name = 'tags[]'
      mockForm.appendChild(selectInput)
      
      controller.showFieldError('tags', 'Please select at least one tag')
      
      expect(selectInput.classList.contains('border-red-500')).toBe(true)
    })
  })

  describe('clearErrors', () => {
    it('clears all error messages and styling', () => {
      const errorMessage = document.createElement('div')
      errorMessage.className = 'field-error-message'
      errorMessage.textContent = 'Error'
      
      const errorField = document.createElement('input')
      errorField.classList.add('border-red-500')
      
      mockElement.appendChild(errorMessage)
      mockElement.appendChild(errorField)
      
      controller.clearErrors()
      
      expect(errorMessage.textContent).toBe('')
      expect(setVisible).toHaveBeenCalledWith(errorMessage, false)
      expect(errorField.classList.contains('border-red-500')).toBe(false)
      expect(setVisible).toHaveBeenCalledWith(mockErrorContainer, false)
    })
  })

  describe('showStatus', () => {
    it('shows status message with correct styling', () => {
      controller.showStatus('Success!', 'success')
      
      expect(mockStatusMessage.textContent).toBe('Success!')
      expect(mockStatusMessage.className).toBe('text-sm mt-2 text-green-600')
      expect(setVisible).toHaveBeenCalledWith(mockStatusMessage, true)
    })

    it('auto-hides success messages', () => {
      jest.useFakeTimers()
      
      controller.showStatus('Success!', 'success')
      
      jest.advanceTimersByTime(3000)
      
      expect(setVisible).toHaveBeenCalledWith(mockStatusMessage, false)
      
      jest.useRealTimers()
    })

    it('defaults to info type', () => {
      controller.showStatus('Information')
      
      expect(mockStatusMessage.classList.contains('text-blue-600')).toBe(true)
    })
  })

  describe('setLoadingState', () => {
    it('disables submit button and shows loading state', () => {
      controller.setLoadingState(true)
      
      expect(mockSubmitButton.disabled).toBe(true)
      expect(mockSubmitButton.innerHTML).toContain('Saving...')
    })

    it('restores submit button when loading false', () => {
      mockSubmitButton.innerHTML = 'Submit'
      controller.setLoadingState(true)
      controller.setLoadingState(false)
      
      expect(mockSubmitButton.disabled).toBe(false)
      expect(mockSubmitButton.innerHTML).toBe('Submit')
    })

    it('disables form inputs during loading', () => {
      const input = document.createElement('input')
      const select = document.createElement('select')
      
      mockForm.appendChild(input)
      mockForm.appendChild(select)
      
      controller.setLoadingState(true)
      
      expect(input.disabled).toBe(true)
      expect(select.disabled).toBe(true)
    })
  })

  describe('validation methods', () => {
    describe('validateEmail', () => {
      it('validates email addresses correctly', () => {
        expect(controller.validateEmail('test@example.com')).toBe(true)
        expect(controller.validateEmail('user+tag@domain.co.uk')).toBe(true)
        expect(controller.validateEmail('invalid-email')).toBe(false)
        expect(controller.validateEmail('test@')).toBe(false)
        expect(controller.validateEmail('@example.com')).toBe(false)
        expect(controller.validateEmail('')).toBe(false)
        expect(controller.validateEmail(null)).toBe(false)
      })
    })

    describe('validatePhone', () => {
      it('validates US phone numbers correctly', () => {
        expect(controller.validatePhone('1234567890')).toBe(true)
        expect(controller.validatePhone('(123) 456-7890')).toBe(true)
        expect(controller.validatePhone('123-456-7890')).toBe(true)
        expect(controller.validatePhone('123.456.7890')).toBe(true)
        expect(controller.validatePhone('12345')).toBe(false)
        expect(controller.validatePhone('123456789012')).toBe(false)
        expect(controller.validatePhone('')).toBe(false)
        expect(controller.validatePhone(null)).toBe(false)
      })
    })

    describe('validateRequired', () => {
      it('validates required fields correctly', () => {
        expect(controller.validateRequired('test')).toBe(true)
        expect(controller.validateRequired('   test   ')).toBe(true)
        expect(controller.validateRequired(['item'])).toBe(true)
        expect(controller.validateRequired('')).toBe(false)
        expect(controller.validateRequired('   ')).toBe(false)
        expect(controller.validateRequired([])).toBe(false)
        expect(controller.validateRequired(null)).toBe(false)
        expect(controller.validateRequired(undefined)).toBe(false)
      })
    })

    describe('validateMinLength', () => {
      it('validates minimum length correctly', () => {
        expect(controller.validateMinLength('hello', 3)).toBe(true)
        expect(controller.validateMinLength('hi', 3)).toBe(false)
        expect(controller.validateMinLength('   hello   ', 5)).toBe(true)
        expect(controller.validateMinLength('', 1)).toBe(false)
        expect(controller.validateMinLength(null, 1)).toBe(false)
      })
    })

    describe('validateMaxLength', () => {
      it('validates maximum length correctly', () => {
        expect(controller.validateMaxLength('hi', 5)).toBe(true)
        expect(controller.validateMaxLength('hello world', 5)).toBe(false)
        expect(controller.validateMaxLength('', 5)).toBe(true)
        expect(controller.validateMaxLength(null, 5)).toBe(true)
      })
    })

    describe('validateRange', () => {
      it('validates numeric ranges correctly', () => {
        expect(controller.validateRange('5', 1, 10)).toBe(true)
        expect(controller.validateRange(5, 1, 10)).toBe(true)
        expect(controller.validateRange('15', 1, 10)).toBe(false)
        expect(controller.validateRange('0', 1, 10)).toBe(false)
        expect(controller.validateRange('abc', 1, 10)).toBe(false)
      })
    })

    describe('validateDate', () => {
      it('validates date format correctly', () => {
        expect(controller.validateDate('12/25/2023')).toBe(true)
        expect(controller.validateDate('1/1/2023')).toBe(true)
        expect(controller.validateDate('2/29/2024')).toBe(true) // Leap year
        expect(controller.validateDate('2/29/2023')).toBe(false) // Not leap year
        expect(controller.validateDate('13/1/2023')).toBe(false) // Invalid month
        expect(controller.validateDate('12/32/2023')).toBe(false) // Invalid day
        expect(controller.validateDate('2023-12-25')).toBe(false) // Wrong format
        expect(controller.validateDate('')).toBe(false)
        expect(controller.validateDate(null)).toBe(false)
      })
    })

    describe('validateFields', () => {
      it('validates multiple fields with rules', () => {
        const data = {
          name: '',
          email: 'invalid-email',
          phone: '123',
          age: '150'
        }
        
        const rules = {
          name: [{ required: true, message: 'Name is required' }],
          email: [
            { required: true, message: 'Email is required' },
            { email: true, message: 'Email is invalid' }
          ],
          phone: [{ phone: true, message: 'Phone is invalid' }],
          age: [{ range: { min: 0, max: 120 }, message: 'Age must be 0-120' }]
        }
        
        const result = controller.validateFields(data, rules)
        
        expect(result.errors).toEqual({
          name: ['Name is required'],
          email: ['Email is invalid'],
          phone: ['Phone is invalid'],
          age: ['Age must be 0-120']
        })
      })

      it('passes validation with valid data', () => {
        const data = {
          name: 'John Doe',
          email: 'john@example.com'
        }
        
        const rules = {
          name: [{ required: true }],
          email: [{ required: true }, { email: true }]
        }
        
        const result = controller.validateFields(data, rules)
        
        expect(result.valid).toBe(true)
        expect(Object.keys(result.errors || {})).toHaveLength(0)
      })
    })
  })

  describe('event handlers', () => {
    it('sets up form event handlers on connect', () => {
      const addEventListener = jest.spyOn(mockForm, 'addEventListener')
      
      controller._setupFormHandlers()
      
      expect(addEventListener).toHaveBeenCalledWith('submit', expect.any(Function))
      expect(addEventListener).toHaveBeenCalledWith('input', expect.any(Function))
      expect(addEventListener).toHaveBeenCalledWith('change', expect.any(Function))
    })

    it('tears down event handlers on disconnect', () => {
      const removeEventListener = jest.spyOn(mockForm, 'removeEventListener')
      
      controller._setupFormHandlers()
      controller._teardownFormHandlers()
      
      expect(removeEventListener).toHaveBeenCalledWith('submit', expect.any(Function))
      expect(removeEventListener).toHaveBeenCalledWith('input', expect.any(Function))
      expect(removeEventListener).toHaveBeenCalledWith('change', expect.any(Function))
    })

    it('clears field errors on input', () => {
      const input = document.createElement('input')
      input.name = 'test'
      input.classList.add('border-red-500')
      
      const parent = document.createElement('div')
      parent.appendChild(input)
      
      const event = { target: input }
      
      controller.clearFieldError(event)
      
      expect(input.classList.contains('border-red-500')).toBe(false)
    })
  })
}) 