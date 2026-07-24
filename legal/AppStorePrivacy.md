# App Store privacy declarations (DRAFT)

> **STATUS: DRAFT — NOT YET IN FORCE.** This document was prepared as a working draft to be finalised and approved by a qualified Nigerian lawyer and the organisation's data-protection contact before publication or reliance. It is not legal advice.

Data map for Apple "App Privacy" and Google Play "Data safety". Complete at
submission against the shipping build.

| Data type | Collected? | Linked to identity | Purpose | Notes |
|-----------|-----------|--------------------|---------|-------|
| Contact info (email, phone) | Yes (accounts only) | Yes | App functionality (safety) | Encrypted; optional — core app needs none |
| Precise location | Yes (Custody Alert only) | Yes, during an alert | App functionality (safety) | Not collected in the background; purged after incident |
| User content (contributions, error reports) | Yes | Optional | App functionality | Reviewed before publication |
| Identifiers (device id) | Yes | No | Rate limiting / abuse prevention | Not for tracking |
| Diagnostics (AI telemetry) | Yes | No | App performance | No question text |

**Tracking:** none. **Data sold:** none. Required permission justifications: location
(Custody Alert), SMS (Android direct alert), notifications (safety follow-ups).
