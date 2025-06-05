# Security Documentation

This directory contains operational security documentation for the Mat Vulcan application.

## Contents

- **`controls.yaml`** - Machine-readable security controls catalog with NIST/DoIT framework mappings
- **`baseline_policy.md`** - Comprehensive security policy document for Maryland DoIT compliance  
- **`authentication_system.md`** - Technical documentation of the current authentication and 2FA system

## Recent Updates

- **2025-05-31**: PII encryption implementation completed using Rails ActiveRecord Encryption for all sensitive database columns

## Purpose

These documents define and document the security posture of the Mat Vulcan application. They are actively maintained and referenced during:

- Security reviews and audits
- Compliance assessments
- Incident response
- Security architecture decisions

## Related Documentation

- **Compliance materials**: See `docs/compliance/` for audit checklists and reporting requirements
- **Future security work**: See `docs/future_work/` for planned security implementations
- **Development security practices**: See `docs/development/` for security-related development guides

## Maintenance

The `controls.yaml` file is validated in CI and should be updated whenever security controls are modified. The policy documents should be reviewed quarterly as part of the security review process.
