# Data Retention Schedule (DRAFT)

> **STATUS: DRAFT — NOT YET IN FORCE.** This document was prepared as a working draft to be finalised and approved by a qualified Nigerian lawyer and the organisation's data-protection contact before publication or reliance. It is not legal advice.

This mirrors `backend/retention.py`, which enforces it automatically. **Change both
together.** Content and the audit log are intentionally exempt (see below).

| Data class | Retention | Rationale |
|------------|-----------|-----------|
| Custody Alert location | **0 days** at rest | Purged as soon as the incident window closes; never retained beyond active delivery |
| Resolved/cancelled alert + deliveries | 30 days | Brief window for the user to review, then deleted |
| AI usage telemetry (no prompt text) | 90 days | Capacity and cost reporting |
| AI answer cache | 1 day | Also bounded by each entry's TTL |
| Abuse / rate-limit counters | 30 days | Short rolling window |
| Verification tokens | 1 day | Single-use, short-lived |
| Delivery-callback (webhook) events | 30 days | Deduplicate provider retries |

**Exempt from automatic purge (by design):**
- **Trust audit log** — permanent; the integrity of the review trail depends on it
  (`GOVERNANCE.md` §7).
- **Versioned content** — immutable-versioned for rollback and provenance.
- **User profile** — kept until the user deletes their account (`DataSubjectRights.md`).
