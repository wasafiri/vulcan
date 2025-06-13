# JavaScript Architecture

A concise reference to the Stimulus-based, service-driven JS layer that powers our Rails app.

---

## 1 · Core Ideas

| Principle | In Practice |
|-----------|-------------|
| **Centralised services** | One request / chart / debounce utility used by every controller. |
| **Base controllers** | Shared form & chart logic via inheritance. |
| **Target-first** | Every DOM dependency declared in `static targets`. |
| **Event-driven** | Controllers communicate through custom events, not direct calls. |
| **Fail-fast** | Missing targets & unhandled errors surface immediately. |

---

## 2 · Key Services

### 2.1 · `rails_request`

```javascript
// app/javascript/services/rails_request.js
const result = await railsRequest.perform({
  method: 'patch',
  url:    '/api/users/123',
  body:   { name: 'John' },
  key:    'user-update'          // duplicates auto-cancelled
})
if (result.success) { ... } else if (!result.aborted) { ... }
```

* Cancels duplicate requests (`key`).  
* Parses JSON, HTML, or Turbo Streams automatically.  
* Global `unhandledrejection` handler silences known @rails/request.js parsing bugs.  
* Upload progress + memory cleanup.

### 2.2 · `chart_config`

```javascript
const config   = chartConfig.getConfigForType('bar', { plugins: { title: { text: 'Revenue' } } })
const datasets = chartConfig.createDatasets([{ label: 'YTD', data }])
```

* Unified colours & typography.  
* ARIA labels baked-in.  
* “Compact” presets for tight layouts.

### 2.3 · Utility Modules

| Utility | Purpose |
|---------|---------|
| `utils/visibility.js` | `setVisible(el, bool, { required })` → toggles `hidden` & `required`. |
| `utils/debounce.js`   | Pre-tuned debounce fns (`createSearchDebounce`, `createFormChangeDebounce`, …). |

---

## 3 · Base Controllers

### 3.1 · `BaseFormController`

* Loader button states, field-level errors, status flash, autosubmit hooks.  
* Integrates `rails_request`; overrides: `validateBeforeSubmit`, `handleSuccess`, `handleError`.

```javascript
class UserFormController extends BaseFormController {
  async validateBeforeSubmit(data) {
    return data.email ? { valid: true } : { valid: false, errors: { email: 'Required' } }
  }
  handleSuccess(data) { this.showStatus('Saved', 'success') }
}
```

### 3.2 · `ChartBaseController`

* Creates <canvas>, destroys Chart.js instance on disconnect, pulls defaults from `chart_config`.

---

## 4 · Target Safety

```javascript
import { applyTargetSafety } from "../mixins/target_safety"

class MyController extends Controller {
  static targets = ['submit', 'status']
  connect() {
    if (!this.hasRequiredTargets('submit')) return
  }
  save() {
    this.withTarget('submit', btn => btn.disabled = true)
  }
}
applyTargetSafety(MyController)
```

* `withTarget / withTargets` helpers never return `null`.  
* `hasRequiredTargets` validates dependencies once.

HTML pattern:

```erb
<form data-controller="my" data-my-target="form">
  <button data-my-target="submit">Save</button>
  <div   data-my-target="status"></div>
</form>
```

---

## 5 · Flash Notifications

```javascript
// controllers/ui/flash_controller.js (outlet target)
this.flashOutlet.showSuccess('Saved!')
```

* Toasts rendered once, styled consistently.  
* Any controller with `static outlets = ['flash']` can push messages.

---

## 6 · Event-Driven Workflows (Paper App Example)

1. **UserSearchController** creates guardian → dispatches success.  
2. **GuardianPickerController** selects guardian → dispatches `selectionChange`.  
3. **ApplicantTypeController** listens → toggles dependent fields → dispatches `applicantTypeChanged`.  
4. **DependentFieldsController** shows appropriate inputs.

Each step uses `this.dispatch('event-name', { detail })`, decoupling controllers.

---

## 7 · Form Data Helpers

```javascript
// Convert nested guardian_attributes[...] names → flat JSON
const data = railsRequest.formDataToJson(formElement, 'guardian_attributes')
await railsRequest.perform({ method:'post', url:'/admin/users', body: data })
```

* Handles radio / checkbox nuances.  
* Sets JSON headers automatically.

---

## 8 · Managed Event Handlers

```javascript
import { EventHandlerMixin } from "../mixins/event_handlers"
Object.assign(MyCtrl.prototype, EventHandlerMixin)

connect() {
  this.initializeEventHandlers()
  this.addManagedEventListener(window, 'resize', this.handleResize)
}
disconnect() { this.cleanupAllEventHandlers() }
```

* All listeners cleaned up on `disconnect`, preventing leaks.

---

## 9 · Testing Patterns

```javascript
test('rails_request cancels dupes', async () => {
  const p1 = railsRequest.perform({ url:'/x', key:'k' })
  const p2 = railsRequest.perform({ url:'/x', key:'k' })
  expect((await p1).aborted).toBe(true)
  expect((await p2).success).toBe(true)
})

test('visibility utility toggles required', () => {
  setVisible(input, true,  { required:true  })
  setVisible(input, false, { required:false })
})
```

* Jest + DOM testing library for utilities.  
* Controllers tested via fixture + fake timers for debounce.

---

## 10 · Production Safeguards

| Concern | Mitigation |
|---------|------------|
| Excess logs | `if (process.env.NODE_ENV !== 'production') { console.log(...) }` |
| Chart leaks | `chartInstance.destroy()` in `disconnect()` |
| Request leaks | Pass a `key`, call `railsRequest.cancel(key)` in `disconnect()` |
| Accessibility | All dynamic elements get ARIA roles / SR-friendly updates |

---

## 11 · Future Work

* Centralise validation rules (move more into `BaseFormController`).  
* Turbo-Stream responses for richer server-side updates.  
* Tree-shake unused Chart.js plugins.  
* Expand `data-testid` usage for more stable selectors.