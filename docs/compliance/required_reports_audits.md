# Required Security Reports & Audits

> Consolidated guide for scheduled security assessments, tests, and audits required under Maryland DoIT and internal policy.  
> Use this as a task-driven checklist and reference for quarterly, annual, and continuous activities.

---

## Overview

All Mat Vulcan environments and third-party services must adhere to a defined schedule of security reports and audits. This document breaks down each requirement by frequency, outlines responsible parties, and describes the actionable steps for completion.

---

## Quarterly Tasks

1. **Vulnerability Scans (External & Internal)**
   - Tools: Industry-standard network and web application scanners.  
   - Steps:
     - Schedule automated scan at start of quarter.  
     - Export scan report (PDF/CSV).  
     - Triage all findings by severity:
       - Critical & High → assign remediation tickets (due within 30 days).  
       - Medium → review and schedule patch or workaround.  
       - Low → document and monitor.  
     - Update `docs/security/controls.yaml` audit.coverage and next_review_due.

2. **Static Application Security Testing (SAST)**
   - Tool: Brakeman  
   - Steps:
     - Run `bin/brakeman` as part of CI or manually via `bundle exec brakeman`.  
     - Review new warnings and false positives.  
     - Create remediation PRs for code fixes.  
     - Verify fixes by re-running Brakeman scan.  

3. **Dependency & SBOM Scanning (SCA)**
   - Tools: `bundler-audit`, Dependabot, CycloneDX SBOM  
   - Steps:
     - Run `bundle exec bundler-audit` in CI; fix or suppress false positives.  
     - Review Dependabot pull requests; merge or close.  
     - Generate SBOM (`bundle exec cyclonedx …`); publish to artifact store.  
     - Update Software Composition Analysis report.

4. **Centralized Log Review & Alert Validation**
   - Platform: SIEM (Security Information and Event Management) system  
   - Steps:
     - Review authentication failure spikes, privilege-use anomalies, and error-rate alerts.  
     - Validate that log retention ≥ 1 year is operational.  
     - Tune thresholds or alert rules as needed.  
     - Document findings in quarterly security report.

5. **Control Self-Assessment**
   - Tool: `docs/security/controls.yaml`  
   - Steps:
     - Run CI lint and test for security YAML.  
     - Manually verify `audit.next_review_due` dates and statuses.  
     - Mark completed controls; open tasks for pending items.

---

## Annual Tasks

1. **Independent Penetration Test**
   - Scope: Full application, infrastructure, API, and third-party integrations.  
   - Steps:
     - Identify vendor to conduct test. 
     - Receive and review final report from vendor.  
     - Assign high-severity findings → remediation tickets (due within 60 days).  
     - Document closure.

2. **NIST CSF Self-Assessment & ATO Package Refresh**
   - Requirements: Self-assessment ≥ Maturity 1, SSP, RA, POA&M, SAR.  
   - Steps:
     - Complete CSF maturity questionnaire by June 30.  
     - Update SSP, RA, POA&M documents under `docs/security/`.  
     - Submit ATO package to OSM; track acceptance.

3. **Encryption Key Rotation**
   - Scope: Envelope encryption keys for ActiveRecord credentials.  
   - Steps:
     - Rotate keys via Rails credentials (`bin/rails credentials:edit`).  
     - Deploy updated credentials to production and staging.  
     - Verify application can decrypt existing data.
   - Note: PII encryption implementation completed 2025-05-31; all sensitive columns now encrypted.

4. **Audit Trail & PaperTrail Review**
   - Scope: Sensitive models (User, Application, etc.).  
   - Steps:
     - Export change-history logs for the past year.  
     - Spot-check 5 random records per model for completeness.  
     - Confirm PaperTrail retention and integrity.

---

## Continuous & Ongoing Activities

- **Automated Intrusion Detection Checks**
  - Integrate OS-level IDS or cloud guardrails.  
  - Monitor alerts daily; escalate as needed.

- **Error-Handling & Exception Logging**
  - Verify an exception tracking system (e.g., Sentry) captures and aggregates all exceptions.  
  - Review monthly exception dashboard for spikes.

- **Patch Management (Weekly)**
  - Triages Dependabot alerts weekly.  
  - Apply critical Ruby/Rails patches within 30 days.

- **Two-Factor Authentication Verifications**
  - Quarterly check of MFA enrollment rates.  
  - Ensure no bypasses or disabled flows exist.

---

## Responsibilities & Ownership

| Task                                   | Team / Owner      |
| -------------------------------------- | ----------------- |
| Vulnerability & SCA Scans              | Engineering Lead  |
| Brakeman & SAST Reviews                | Security Engineer |
| Penetration Testing Coordination       | Security Manager  |
| CSF Self-Assessment & ATO Submission   | Compliance Lead   |
| Encryption Key Rotation                | DevOps Team       |
| Log Review & Alert Tuning              | Operations Team   |
| Patch & Dependency Management          | Engineering Team  |

---

## How to Use This Guide

1. At each period start (quarter/annual), consult the relevant section.  
2. Tick off each actionable sub-task and record completion dates.  
3. Update both this document and `docs/security/controls.yaml` to reflect changing statuses.  
4. Archive past reports under `docs/security/reports/YYYY-QX/` for audit traceability.
