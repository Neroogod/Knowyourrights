# Record of Processing Activities (DRAFT)

> **STATUS: DRAFT — NOT YET IN FORCE.** This document was prepared as a working draft to be finalised and approved by a qualified Nigerian lawyer and the organisation's data-protection contact before publication or reliance. It is not legal advice.

Maintained by the DP contact per NDPA. One row per processing activity.

| Activity | Data categories | Subjects | Lawful basis | Recipients | Retention | Security |
|----------|-----------------|----------|--------------|-----------|-----------|----------|
| Account & auth | email, password hash | users | contract | hosting | until deletion | Argon2, TLS, RBAC |
| Safety profile | name, phone (encrypted) | users | consent | none | until deletion | Fernet-at-rest, TLS |
| Emergency contacts | name, phone/email (encrypted) | contacts of users | consent | delivery processors | until removed | encrypted, TLS |
| Custody Alert | location, identity, time | users | consent / vital interests | chosen contacts | location 0 days; alert 30 days | encrypted, purged |
| AI telemetry | corpus, latency, cost, refusal (no prompt) | anonymous/users | legitimate interest | none | 90 days | aggregate only |
| Error reports | message, target, optional reporter | anyone | legitimate interest | reviewers | with content | audit-logged |

Processors: hosting (PaaS), email (Resend), SMS (Twilio). Each under a data-processing
agreement. Cross-border transfer assessment: **[TO CONFIRM per processor region]**.
