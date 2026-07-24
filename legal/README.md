# Legal & privacy operations

> **STATUS: DRAFT — NOT YET IN FORCE.** This document was prepared as a working draft to be finalised and approved by a qualified Nigerian lawyer and the organisation's data-protection contact before publication or reliance. It is not legal advice.

This folder holds the organisational legal and privacy work for KnowYourRights.
The technical enforcement lives in code (`backend/retention.py` runs the retention
schedule; encryption and access control live in `backend/accounts.py`); these
documents are the policies that code enforces, plus the ones that need a human
signature.

## Documents

| Document | Purpose | Status |
|----------|---------|--------|
| `PRIVACY-POLICY.md` | What data we process and why (NDPA 2023) | DRAFT — counsel review |
| `TERMS-OF-SERVICE.md` | Terms of use and liability posture | DRAFT — counsel review |
| `DISCLAIMER.md` | The "information, not advice" disclaimer | DRAFT — counsel review |
| `DPIA-CustodyAlert.md` | Data Protection Impact Assessment for Custody Alert | DRAFT — DPO sign-off |
| `RecordOfProcessing.md` | Record of Processing Activities (RoPA) | DRAFT — DPO maintains |
| `RETENTION-SCHEDULE.md` | How long each data class is kept (mirrors code) | DRAFT — counsel review |
| `DataSubjectRights.md` | Access, export, and erasure procedure | DRAFT — counsel review |
| `AppStorePrivacy.md` | Apple/Google privacy declarations | DRAFT — complete at submission |
| `ContributorAgreement.md` | IP licence for contributed content | DRAFT — counsel review |
| `SourceProvenance.md` | Source licensing register + sign-off | DRAFT — decisions pending |

The **editorial policy** — what qualifies as verified content, conflict handling,
and final sign-off — is `../GOVERNANCE.md`. It is not duplicated here.

## Decisions a person must make (cannot be resolved in code)

1. **Appoint a data-protection contact / DPO.** Every document below references a
   DP contact; the role and a real contact must be named before launch.
2. **LED 605 (NOUN course) licensing.** Decide whether to license the material or
   drop it; until decided, it is not used as source content. See `SourceProvenance.md`.
3. **NWLR / law-report licensing.** Confirmed as *cite-and-link only* in the build
   plan; a signed acknowledgement of that limitation belongs in `SourceProvenance.md`.
4. **Counsel review of every document here**, and of the seed legal content
   (`GOVERNANCE.md` §9 records that it is cited but not yet lawyer-reviewed).
