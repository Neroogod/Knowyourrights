# Data-subject rights: access, export, erasure (DRAFT)

> **STATUS: DRAFT — NOT YET IN FORCE.** This document was prepared as a working draft to be finalised and approved by a qualified Nigerian lawyer and the organisation's data-protection contact before publication or reliance. It is not legal advice.

## In the app
**Settings → Your data**: *Export my data* (JSON) and *Delete my account*.

## Endpoints
- `GET /v1/account/export` — machine-readable copy of the account's data.
- `DELETE /v1/account` (confirmation required) — erases the account and its
  personal data; audit-log entries are retained but no longer identify the person
  beyond what the trail legally requires.

## Manual requests
A data subject may contact the DP contact for access, correction, erasure, or
portability. Target response: **within the NDPA statutory period**. Verify identity
before acting. Log each request and its outcome.

## Erasure scope
Erasure removes profile, contacts, saved items, and preferences. It does **not**
remove aggregate, non-identifying telemetry (already prompt-free) or immutable
audit entries required for integrity — this limitation is disclosed in the Privacy
Policy.
