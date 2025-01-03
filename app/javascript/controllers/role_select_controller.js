// app/javascript/controllers/role_select_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "button", "feedback"]

  connect() {
    this.originalRole = this.selectTarget.value
    this.buttonTarget.disabled = true
  }

  roleChanged() {
    this.buttonTarget.disabled = this.selectTarget.value === this.originalRole
  }

  async updateRole(event) {
    const userId = event.currentTarget.dataset.userId
    const role = this.selectTarget.value
    const button = event.currentTarget
    
    try {
      button.disabled = true
      button.innerHTML = 'Updating...'

      const response = await fetch(`/admin/users/${userId}/update_role`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ role })
      })

      const data = await response.json()

      if (!response.ok) {
        throw new Error(data.message || 'An unexpected error occurred')
      }

      this.showFeedback(data.message, 'success')
      this.originalRole = role
    } catch (error) {
      this.showFeedback(error.message, 'error')
    } finally {
      button.disabled = false
      button.innerHTML = 'Update Role'
    }
  }

  showFeedback(message, type) {
    const feedback = this.feedbackTarget
    feedback.classList.remove('hidden')
    feedback.classList.add(type === 'success' ? 'bg-green-50' : 'bg-red-50')
    feedback.innerHTML = `
      <div class="flex items-center p-4">
        <div class="flex-shrink-0">
          ${type === 'success' 
            ? '<svg class="h-5 w-5 text-green-400" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>'
            : '<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>'
          }
        </div>
        <div class="ml-3">
          <p class="text-sm font-medium ${type === 'success' ? 'text-green-800' : 'text-red-800'}">
            ${message}
          </p>
        </div>
      </div>
    `

    setTimeout(() => {
      feedback.classList.add('hidden')
    }, 3000)
  }
}