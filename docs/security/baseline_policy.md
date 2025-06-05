# Security Baseline Policy

> **Audience** — Engineering, Security, & Compliance teams building and operating the **Mat Vulcan** Ruby on Rails application for public use under Maryland DoIT rules.
>
> **Last updated:** 2025-05-22 (aligned to DoIT consolidated guidance v2025-05)

---

## Overview

This document outlines **all external compliance obligations** (Maryland DoIT directives & minimum standards) **and our internal security controls**.  It supersedes prior versions of this policy document.

It applies to:

* Mat Vulcan code, infrastructure, and data flows.
* Production, staging, and developer-preview environments.
* Third-party services directly handling agency data (e.g., Heroku, Sentry, Twilio).

---

## Quick-Look DoIT Checklist  ↻

Tick **every** box before requesting an Authorization-to-Operate (ATO) or major release:

| ✅ / ⬜︎ | Requirement                                                                                 | Source(s)                                                                                        |
| ------ | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| ✅     | Remove prohibited tech & vendors (TikTok, Kaspersky, Huawei, etc.).  None are used in the codebase. Confirmed 5/22/25.                      | **Emergency Directive 2022-12-001**                                                              |
| ✅     | MFA for **all external users** *and* every remote admin session.                            | **IT Security Manual IA-2**, **External User Auth G21-1**, **State Min Cyber Standards PR.AC-1** |
| ⬜︎     | Maintain complete asset & software inventory; map all data flows.                           | **State Min Cyber Standards ID.AM-1/2**, **CSF Guidebook ID.AM**                                 |
| ✅     | Encrypt data *in transit* (TLS 1.2+) & *at rest* (AES-256 / Rails ActiveRecord Encryption) — completed 2025-05-31. | **IT Security Manual SC-13**, **CSF Guidebook PR.DS-2**                                          |
| ⬜︎     | Annual independent penetration test + quarterly vulnerability scans. Vendor for independent penetration test, and scripts for quarterly vulnerability scans needed. Specific tools are documented in `docs/security/controls.yaml`. | **IT Security Manual CA-2.1 & RA-5**, **CSF Guidebook DE.CM-8**                                  |
| ✅     | Centralised logs retained ≥ 1 year; alert on auth failure spikes & privilege misuse.        | **State Min Cyber Standards DE.AE-1/2**, **CSF Guidebook DE controls**                           |
| ⬜︎     | Submit Statement of Compliance & full ATO package to OSM before launch.                     | **IT Security Manual CA-1/2**, **State Min Cyber Standards Appendix A**                          |

---

## Table of Contents

* [Maryland DoIT Core Security Principles](#maryland-doit-core-security-principles)
* [Rails Security Features](#rails-security-features)
* [Machine-Readable Controls](#machine-readable-controls)
* [Critical Security Files](#critical-security-files)
* [Detailed Security Controls](#detailed-security-controls)

  * [Authentication & Authorization](#authentication--authorization)
  * [Data Protection](#data-protection)
  * [Application Hardening & Configuration](#application-hardening--configuration)
  * [Access Control](#access-control)
  * [Audit & Logging](#audit--logging)
  * [Testing & Vulnerability Management](#testing--vulnerability-management)
  * [Error Handling](#error-handling)
  * [User Management](#user-management)
* [Security Documentation Package (Maryland DoIT)](#security-documentation-package-maryland-doit)
* [Approval Path to Production (Maryland DoIT)](#approval-path-to-production-maryland-doit)
* [Hosting Considerations](#hosting-considerations)
* [Implementation Notes](#implementation-notes)
* [Next Steps](#next-steps)
* [Control Categories & DoIT Alignment](#control-categories--doit-alignment)

---

## Maryland DoIT Core Security Principles

1. **Data Management** — Map data flows and classify data (PII, PHI, FTI, etc.). *Emergency Directive 2022-12-001*
2. **Technology Selection** — Use maintained libraries; ban components on the State Prohibited Technologies list. *Emergency Directive 2022-12-001*
3. **Supply-Chain Security** — Enforce SBOM & SCA scans in CI. *IT Security Manual SI-2, RA-5*
4. **Patch Management** — Patch Ruby/Rails within 30 days of security release. *IT Security Manual RA-5*
5. **Secrets Management** — Rails encrypted credentials or KMS only; never commit secrets. *IT Security Manual SC-13 / IA-7*

---

## Rails Security Features

Mat Vulcan leverages Rails 8+ defaults:

```bash
bin/rails generate authentication
```

Key outputs:

* `app/models/session.rb` — secure session model
* `app/models/current.rb` — thread-safe current user
* `app/controllers/concerns/authentication.rb` — helpers
* RESTful routes for sign-in/out, password reset, MFA setup

### Default security config

Mat Vulcan leverages Rails 8+ defaults for many security configurations. Explicit configurations are noted below.

```ruby
config.force_ssl = true                       # HTTPS + HSTS (explicitly set in config/environments/production.rb)
# config.action_dispatch.cookies_same_site_protection = :lax # Rails 8 default
# config.action_dispatch.default_headers = { # Rails 8 default
#   'X-Frame-Options' => 'SAMEORIGIN',
#   'X-XSS-Protection' => '1; mode=block',
#   'X-Content-Type-Options' => 'nosniff',
#   'Referrer-Policy' => 'strict-origin-when-cross-origin'
# }
# config.filter_parameters += %i[password password_confirmation ssn medical_provider_email] # Rails 8 default; sensitive parameters filtered via config/initializers/filter_parameter_logging.rb
# config.active_record.encryption.add_to_filter_parameters = true # Rails 8 default
```

---

## Machine-Readable Controls

Controls live in `docs/security/controls.yaml` and are linted in CI (**`scripts/lint_security_yaml.rb`**).  Each control tracks status, evidence, DoIT/NIST mapping, and test coverage.

### CI Integration

```yaml
jobs:
  security_controls:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bundle exec ruby scripts/lint_security_yaml.rb
      - run: bundle exec rake test:security_controls
```

SAST (Brakeman) and dependency scans (`bundler-audit`, Dependabot) run on every pull-request.

---

## Critical Security Files

| File                                 | Purpose                      | DoIT alignment | Status                  |
| ------------------------------------ | ---------------------------- | -------------- | ----------------------- |
| `content_security_policy.rb`         | CSP header                   | SC-13          | ⚠️ review nonce rollout |
| `two_factor_auth.rb` / `webauthn.rb` | MFA config                   | IA-2 / G21-1   | ✅                       |
| `credentials.yml.enc`                | Secrets store                | SC-13 / IA-7   | ✅                       |

---

## Detailed Security Controls

### Authentication & Authorization

#### AUTH-001 — User Authentication  *(Critical)*

* **DoIT refs:** IA-2, PR.AC-1
* **Status:** Implemented; verify BCrypt cost ≥12.
* **Action:** Spike Argon2id/PBKDF2 option ➜ **target: 2025-06-30**.

#### AUTH-002 — Multi-Factor Authentication *(Critical)*

* **DoIT refs:** IA-2, G21-1
* **Status:** WebAuthn + TOTP + SMS enforced for all external users and admins.

#### AUTH-003 — Password Policy *(High)*

* **DoIT refs:** PR.AC-1
* **Status:** Needs review (see AUTH-001 action).

#### AUTH-004 — Session Management *(High)*

* **DoIT refs:** PR.AC-1
* **Status:** Secure cookies, 30-min idle timeout, fixation reset.

### Data Protection

#### DATA-001 — Encryption *(Critical)*

* **DoIT refs:** SC-13, PR.DS-2
* **Status:** ✅ **Completed** — TLS 1.2+ enforced; AES-256 at rest encryption via ActiveRecord `encrypts` implemented for all sensitive columns (completed 2025-05-31).

#### DATA-002 — Input Validation & Filtering *(High)*

* **DoIT refs:** SC-13 / IA-7
* **Status:** Strong params; sensitive attr filtering; upload validation.

#### DATA-003 — CSRF Protection *(High)*

* **DoIT refs:** PR.IP-9
* **Status:** `protect_from_forgery` everywhere; API exceptions documented.

### Application Hardening & Configuration

#### CONFIG-001 / CONFIG-002 *(Critical)*

* **DoIT refs:** SC-13 / IA-7
* **Status:** Implemented.
* HTTPS, HSTS (2y preload), CSP, permission policy, secrets in KMS.

### Access Control

#### AUTHZ-002 — Authorization Checks *(Critical)*

* **DoIT refs:** PR.AC-4
* **Status:** Role & capability checks across controllers.

#### AUTHZ-003 — API Security *(High)*

* **DoIT refs:** PR.AC-4
* **Status:** Token auth, rate-limiting, schema validation.

### Audit & Logging

#### AUDIT-001 — Security Logging *(High)*

* **DoIT refs:** DE.AE-1/2
* **Status:** CloudWatch → SumoLogic; retention 400 days; auth anomaly alerts live.

#### AUDIT-002 — Audit Trail *(Medium)*

* **DoIT refs:** AU-3
* **Status:** Change history on sensitive models.

### Testing & Vulnerability Management

#### TEST-001 — Security Testing & Assessment *(Critical)*

* **DoIT refs:** CA-2.1, RA-5, SI-2
* **Status:** SAST & dependency scans are integrated into CI. An annual third-party penetration test is **scheduled for Q3-2025**. Patching of critical vulnerabilities adheres to an SLO of ≤ 30 days.

### Error Handling

#### ERROR-001 / ERROR-002 *(High)*

* **DoIT refs:** PR.DS-6
* **Status:** Friendly error pages; exception logging.

### User Management

(Registration, account, guardian/dependent, vendor — reviewed; align with IA-2 & PR.AC-1.)

---

## Security Documentation Package (Maryland DoIT)

* SSP, RA & POA\&M, SAR, Contingency/Backup Plan, IRP, Change-Control, Statement of Compliance — stored under `docs/security/*`.

---

## Approval Path to Production (Maryland DoIT)

1. **Secure SDLC evidence** (CI reports, threat model).
2. **NIST CSF Self-Assessment** (≥1 maturity; file by June 30).
3. **Independent Security Assessment** (pen-test, control review).
4. **ATO Package** (SSP + SAR + POA\&M) — valid 3 years.
5. **Change Approval** (firewall/DNS/TLS review).
6. **Continuous Monitoring** (quarterly scans, SIEM alerts, annual control test).

---

## Hosting Considerations

### DoIT-Managed IaaS vs. **Heroku Shield**

| Criteria                 | DoIT‑Managed IaaS       | **Heroku Shield** on AWS GovCloud                                                                                               |
| ------------------------ | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Data Sensitivity         | Highest (CJIS, FTI)     | Moderate (PII/PHI)                                                                                                              |
| Provisioning Speed       | Weeks‑months            | Minutes‑hours                                                                                                                   |
| Compliance Coverage      | State bespoke controls  | HIPAA, SOC 2 Type II, ISO 27001/17/18                                                                                           |
| Ops Flexibility          | Limited to DoIT tooling | Full DevOps pipelines                                                                                                           |
| Contractual Requirements | Standard MOU            | **Add‑on:**<br>• FedRAMP‑Moderate parity<br>• NIST SP 800‑144 clauses<br>• Right‑to‑audit<br>• Data return / secure destruction |

(The "Heroku Implementation Notes" that were previously part of the user-provided version are now located under the "Implementation Notes" section of this document.)

---

## Implementation Notes

* Secrets rotation via Doppler + KMS (90-day schedule).
* CSP nonce rollout planned.
* Table-top IR test Q4-2025.

---

## Next Steps

1. Update `controls.yaml` with new TEST-001 & CONFIG status.
2. Complete Argon2id spike (due 2025-06-30).
3. Auto-generate checklist section from YAML to avoid drift.

---

## Control Categories & DoIT Alignment

(see YAML for exhaustive mapping; high-level list retained for quick search.)
