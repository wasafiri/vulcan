import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "code", "amount", "codeStatus", "amountStatus", "submit" ]
  
  connect() {
    this.validateForm()
    this.checkVoucherTimeout = null
  }

  validateCode() {
    const code = this.codeTarget.value.toUpperCase()
    this.codeTarget.value = code // Force uppercase

    if (code.length === 0) {
      this.codeStatusTarget.textContent = "Enter the 12-character voucher code"
      this.codeStatusTarget.className = "mt-2 text-sm text-gray-500"
    } else if (code.length !== 12) {
      this.codeStatusTarget.textContent = "Voucher code must be 12 characters"
      this.codeStatusTarget.className = "mt-2 text-sm text-red-600"
    } else if (!/^[A-Z0-9]+$/.test(code)) {
      this.codeStatusTarget.textContent = "Only letters and numbers are allowed"
      this.codeStatusTarget.className = "mt-2 text-sm text-red-600"
    } else {
      // Clear any existing timeout
      if (this.checkVoucherTimeout) {
        clearTimeout(this.checkVoucherTimeout)
      }
      
      // Set a new timeout to check the voucher after a short delay
      this.checkVoucherTimeout = setTimeout(() => {
        this.checkVoucherBalance(code)
      }, 300)
    }

    this.validateForm()
  }
  
  async checkVoucherBalance(code) {
    this.codeStatusTarget.textContent = "Checking voucher..."
    this.codeStatusTarget.className = "mt-2 text-sm text-gray-500"
    
    try {
      const response = await fetch(`/vendor/redemptions/check_voucher?code=${code}`)
      const data = await response.json()
      
      if (data.valid) {
        this.codeStatusTarget.textContent = `Valid voucher - Available balance: ${data.formatted_value}`
        this.codeStatusTarget.className = "mt-2 text-sm text-green-600 font-medium"
        
        // Set max amount to the remaining value
        this.amountTarget.max = data.remaining_value
      } else {
        this.codeStatusTarget.textContent = data.message
        this.codeStatusTarget.className = "mt-2 text-sm text-red-600"
      }
    } catch (error) {
      this.codeStatusTarget.textContent = "Error checking voucher"
      this.codeStatusTarget.className = "mt-2 text-sm text-red-600"
      console.error("Error checking voucher:", error)
    }
  }

  validateAmount() {
    const amount = parseFloat(this.amountTarget.value)
    const minAmount = parseFloat(this.amountTarget.min)
    const maxAmount = parseFloat(this.amountTarget.max || Infinity)

    if (isNaN(amount)) {
      this.amountStatusTarget.textContent = `Minimum amount: $${minAmount.toFixed(2)}`
      this.amountStatusTarget.className = "mt-2 text-sm text-gray-500"
    } else if (amount < minAmount) {
      this.amountStatusTarget.textContent = `Amount must be at least $${minAmount.toFixed(2)}`
      this.amountStatusTarget.className = "mt-2 text-sm text-red-600"
    } else if (amount > maxAmount) {
      this.amountStatusTarget.textContent = `Amount exceeds available balance of $${maxAmount.toFixed(2)}`
      this.amountStatusTarget.className = "mt-2 text-sm text-red-600"
    } else {
      this.amountStatusTarget.textContent = "Valid amount"
      this.amountStatusTarget.className = "mt-2 text-sm text-green-600"
    }

    this.validateForm()
  }

  validateForm() {
    const code = this.codeTarget.value
    const amount = parseFloat(this.amountTarget.value)
    const minAmount = parseFloat(this.amountTarget.min)
    const maxAmount = parseFloat(this.amountTarget.max || Infinity)

    const isValid = code.length === 12 &&
      /^[A-Z0-9]+$/.test(code) &&
      !isNaN(amount) &&
      amount >= minAmount &&
      amount <= maxAmount

    this.submitTarget.disabled = !isValid
  }
}
