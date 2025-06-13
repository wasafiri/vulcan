# MAT Vulcan Application Workflow Guide  
*Last updated Dec 2025 – verified against production code*

---

## Quick Map

```text
Portal User ─────▶ ApplicationCreator ──────┐
                                            │        ▾
Admin  ──▶ PaperApplicationService ──▶ App   │  EventDeduplication
                                            │        ▾
               ProofAttachmentService ←─────┘  Audit & Notification
                    ▲     ▲         ▲
                    │     │         └─ MedicalCertificationService
                    │     └── VoucherAssignment
                    └── GuardianRelationship
```

All flows converge on **one Application record**, so every downstream service (events, proofs, notifications, vouchers) works the same no matter how the app started.

---

## 1 · Core Building Blocks

| Component | Purpose | Notes |
|-----------|---------|-------|
| **ApplicationCreator** | Portal self-service “happy path” | Runs in DB TX; fires events & notifications |
| **PaperApplicationService** | Admin data-entry path | Sets `Current.paper_context` to bypass online-only validations |
| **EventDeduplicationService** | 1-min window, priority pick | Used by audit views, dashboards, certification timelines |
| **NotificationService** | Email / SMS / in-app / fax | Postmark, Twilio integrations |
| **ProofAttachmentService** | Upload / approve / reject | Unified for web, email, paper |
| **MedicalCertificationService** | Request & track med certs | Updates status, sends provider faxes |
| **VoucherAssignment** | Issue & redeem vouchers | Auto-assign on approval, vendor redemption flow |

---

## 2 · Creation Flows

### 2.1 Portal (Constituent)

1. **Auth → Dashboard → “Create Application”**  
2. **5-step form** (type, personal, income, provider, proofs).  
3. **Autosave every 2 s**; live FPL check + file validation.  
4. `ApplicationCreator` service:  
   * Validates data → upserts user → sets guardian link (if needed) → creates Application → attaches proofs → `AuditEventService.log` + `NotificationService`.

### 2.2 Paper (Admin)

1. **Admin → Paper Apps → New**  
2. Dynamic form (guardian search / create, proof accept w/ or w/o file).  
3. Wrap all logic with:

```ruby
Current.paper_context = true
begin
  process_paper_application # uses PaperApplicationService
ensure
  Current.reset
end
```

4. Same downstream services as portal flow → single behaviour set.

---

## 3 · Event System (Why you care)

* Admin timelines, user “Activity” tab, medical cert dashboard—all pull from **deduped event lists**.  
* Dedup key: `[fingerprint, minute_bucket]` → pick highest priority (StatusChange > Event > Notification).

```ruby
service = Applications::EventDeduplicationService.new
events  = service.deduplicate(raw_events)
```

When adding a new event type, **just log it**—the service handles dedup for you.

---

## 4 · Notifications in Plain English

| Channel | Stack | Typical Use |
|---------|-------|-------------|
| In-app  | Turbo + read/unread | All status changes |
| Email   | Postmark webhooks   | Proof approved / rejected |
| SMS     | Twilio             | Time-sensitive alerts |
| Fax     | InterFax wrapper   | Provider medical cert requests |

Create once, deliver many:

```ruby
NotificationService.create_and_deliver!(
  type: 'application_submitted',
  recipient: application.user,
  notifiable: application
)
```

Delivery metadata (bounce, spam, sms status) is stored for audit & retries.

---

## 5 · Proof Review in 3 Calls

```ruby
# Upload (user or admin)
ProofAttachmentService.attach_proof(...)
# Approve
ProofReviewService.new(app, admin, params).approve_proof(:income)
# Reject
ProofReviewService.new(app, admin, params).reject_proof(:income, 'blurry')
```

*Paper context auto-approves without a file.*

---

## 6 · Medical Certification Flow

1. `MedicalCertificationService.request_certification`  
   * Bumps counter, logs event, fires fax/email.  
2. Provider replies by **fax or email** → `MedicalCertificationMailbox` consumes → `MedicalCertificationAttachmentService.attach_certification`.  
3. Admin can **reject** or adjust status via UI; auto-approve logic checks all three proof types + income threshold.

---

## 7 · Status Machine (Lite)

```
draft ─▶ in_progress ─▶ approved* ─▶ voucher_assigned ─▶ redeemed
      └▶ rejected
```

*`approved` can be manual (admin) or automatic (`check_auto_approval_eligibility`).*  
All transitions create **ApplicationStatusChange** + notification.

---

## 8 · Guardian / Dependent Cheat Sheet

```ruby
GuardianRelationship.create!(
  guardian_user:  guardian,
  dependent_user: dependent,
  relationship_type: 'Parent'
)
application.user              = dependent
application.managing_guardian = guardian
```

* Notifications for dependent apps go to **guardian**, not child.  
* Dependent contact: `email_strategy` & `phone_strategy` decide whether to clone guardian info or use unique fields.

---

## 9 · Vouchers

* Auto-issued right after approval if policy met.  
* Stored in `vouchers` table, 1-year expiry.  
* Vendor portal hits `redeem_voucher` which creates `VoucherTransaction` + `Invoice`.

---

## 10 · Admin Toolkit Highlights

* **FilterService** handles index search & facets.  
* Dashboard metrics pulled with raw SQL for speed.  
* Bulk ops (`batch_approve`, `batch_reject`) use `Application.batch_update_status`.  
* **AuditLogBuilder** + EventDeduplication = fast, deduped history for show view.

---

## 11 · Integration Hooks

| Service | Endpoint / Job | Purpose |
|---------|----------------|---------|
| Postmark | `/webhooks/email_events` | Delivery / bounce / spam |
| Twilio   | queued job callbacks      | SMS status |
| Medical Cert Fax | `/webhooks/medical_certifications` | Provider replies |
| ActiveStorage   | background scans | Virus scan, metadata |

---

## 12 · How to Extend

* **New proof type?** Add enum, extend `ProofAttachmentService`, update `determine_proof_type`.  
* **New notification?** Add type constant + template; call `NotificationService.create_and_deliver!`.  
* **New status?** Update enum, `ApplicationStatusChange`, auto-approval checks, and front-end filters.  
* **New event?** Just log it with `AuditEventService.log`; dedup handles rest.

---

## 13 · Gotchas & Tips

1. **Always set `Current.paper_context`** in paper tests—or validations will fail.  
2. **Use `rails_request` keys** in JS to prevent duplicate AJAX hits on forms.  
3. **Phone numbers** must be normalised (`555-123-4567`) *before* uniqueness check.  
4. **Event floods** – if you log many similar events in <60 s, the dedup window ensures dashboards stay sane.  
5. **Voucher auto-assign** runs *after* approval callbacks—don’t forget when stubbing in specs.