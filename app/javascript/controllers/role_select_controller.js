// app/javascript/controllers/role_select_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "feedback", "capability"]
  static values = {
    userId: String
  }

  connect() {
    console.log("RoleSelect Controller connected", {
      element: this.element,
      userId: this.userIdValue,
      hasSelectTarget: this.hasSelectTarget,
      hasCapabilityTargets: this.hasCapabilityTargets,
      targetsFound: {
        select: this.selectTarget,
        capabilities: this.capabilityTargets,
        feedback: this.feedbackTarget
      }
    })
  }

  roleChanged(event) {
    console.log("Role changed triggered", {
      userId: this.userIdValue,
      newRole: event.target.value,
      element: event.target,
      currentTarget: event.currentTarget
    })

    const data = {
      role: event.target.value
    }

    console.log("Sending role update with data:", data)
    this.saveChanges('role', data)
  }

  toggleCapability(event) {
    console.log("Capability toggle triggered", {
      userId: this.userIdValue,
      capability: event.target.dataset.capability,
      checked: event.target.checked,
      element: event.target,
      currentTarget: event.currentTarget
    })

    const data = {
      capability: event.target.dataset.capability,
      enabled: event.target.checked
    }

    console.log("Sending capability update with data:", data)
    this.saveChanges('capability', data)
  }

  async saveChanges(changeType, data) {
    console.log("Starting saveChanges", {
      type: changeType,
      userId: this.userIdValue,
      data: data,
      currentState: {
        selectValue: this.selectTarget?.value,
        capabilities: this.capabilityTargets ? [...this.capabilityTargets].map(cb => ({
          name: cb.dataset.capability,
          checked: cb.checked
        })) : []
      }
    })

    const url = `/admin/users/${this.userIdValue}/${changeType === 'role' ? 'update_role' : 'update_capabilities'}`
    console.log("Making request to:", url)

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      console.log("CSRF Token found:", !!csrfToken)

      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(data)
      })

      console.log("Response received", {
        status: response.status,
        ok: response.ok,
        statusText: response.statusText
      })

      if (!response.ok) {
        const errorText = await response.text()
        console.error("Server returned error", {
          status: response.status,
          text: errorText
        })
        throw new Error(errorText || `Server returned ${response.status}`)
      }

      const responseData = await response.json()
      console.log("Response data:", responseData)

      this.showFeedback(responseData.message, 'success')
    } catch (error) {
      console.error("Save failed", {
        error: error,
        message: error.message,
        stack: error.stack
      })

      // (A) Revert the checkbox if it was a capability toggle that failed
      if (changeType === 'capability') {
        const toggledCapability = data.capability
        const toggledCheckbox = this.capabilityTargets.find(cb => cb.dataset.capability === toggledCapability)
        if (toggledCheckbox) {
          // Reverse to the old checked state
          toggledCheckbox.checked = !data.enabled
        }
      }

        this.showFeedback(error.message, 'error')
    }
  }

  showFeedback(message, type) {
    console.log("Showing feedback", {
      message: message,
      type: type,
      feedbackTarget: this.feedbackTarget
    })

    const feedback = this.feedbackTarget
    const isSuccess = type === 'success'

    feedback.classList.remove('hidden')
    feedback.innerHTML = `
      <div class="flex items-center p-2 ${isSuccess ? 'bg-green-50' : 'bg-red-50'} rounded">
        <p class="text-sm ${isSuccess ? 'text-green-700' : 'text-red-700'}">${message}</p>
      </div>
    `

    console.log("Feedback element updated", {
      visible: !feedback.classList.contains('hidden'),
      content: feedback.innerHTML
    })

    setTimeout(() => {
      feedback.classList.add('hidden')
      console.log("Feedback hidden")
    }, 3000)
  }
}
