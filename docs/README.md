# MAT Vulcan Documentation Hub

A roadmap to **every doc, guide, and reference** in the repository—so devs and AI helpers can jump straight to what they need.

---

## 1 · Quick Start

| Step | Where to look | Why |
|------|---------------|-----|
| **1. Feature Overview** | `current_application_features.md` | Know what the app does right now. |
| **2. Test & Debug** | `development/testing_and_debugging_guide.md` | Local setup, CurrentAttributes patterns, debugger tips. |
| **3. Service Patterns** | `development/service_architecture.md` | Understand how business logic is encapsulated. |

> **Tip:** Search the **development/** folder first for any "how do I…?" question -— most implementation guides live there.

---

## 2 · Folder Map

### 📂 development/

Deep-dive, code-facing docs for contributors.

| File | Highlights |
|------|------------|
| `testing_and_debugging_guide.md` | Mini-plan workflow, one-tool-call practice, Current attributes in tests. |
| `service_architecture.md` | All service objects, including **EventDeduplicationService** logic. |
| `guardian_relationship_system.md` | Model graph, contact-strategy helpers. |
| `javascript_architecture.md` | Stimulus target-first pattern, `rails_request` service, base controllers. |
| `paper_application_architecture.md` | Admin paper-form flow, bypass validations with `Current.paper_context`. |
| `user_management_features.md` | Phone/email dedup, `data-testid` naming scheme, factory recipes. |

### 📂 features/

Spec-level docs for discrete user stories.

* `add_alternate_contact_feature.md`  
* `application_pain_point_tracking.md`  
* `email_uniqueness_for_dependents.md`

### 📂 infrastructure/

Ops-level references.

* `email_system.md` – template DB workflow, inbound Action Mailbox, Postmark streams.

### 📂 future_work/

Living backlog and architectural Big-Think.

* `mat_vulcan_todos.md`

### Optional folders (present if needed)

* **compliance/** – regulatory docs  
* **security/** – threat models, key-rotation SOPs  
* **ui_components/** – design-system snippets  
* **guides/** – user-facing manuals

---

## 3 · Doc-Hunting Tips for AI Assistants

| Need | Where to search |
|------|-----------------|
| "How does X feature work?" | `current_application_features.md`, then specific file in **features/** |
| "Which service owns Y?" | `development/service_architecture.md` |
| "What JS pattern should I follow?" | `development/javascript_architecture.md` |
| "Where's the email config?" | `infrastructure/email_system.md` |
| "Upcoming tasks?" | `future_work/mat_vulcan_todos.md` |

Naming is grep-friendly: *feature names* mirror folder/file names, so `"guardian_relationship_system"` appears exactly once per folder.
