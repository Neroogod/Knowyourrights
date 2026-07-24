# Editorial governance

What the Verified badge means, who may grant it, and how it is taken away.

The product's only real asset is that people can trust what it tells them. A badge
is a promise; this document defines the promise, and `backend/review.py` enforces
it in code.

## 1. Roles

| Role | May do | May not do |
|------|--------|-----------|
| **reader** | read everything, report an error | submit or verify content |
| **contributor** | submit content and case interpretations (enters `draft`/`community`) | verify anything |
| **reviewer** (lawyer or legal editor) | approve, reject, or request changes; triage error reports | grant roles |
| **administrator** | manage roles and sources; read the audit log | rewrite the audit log — no such path exists |

A contributor cannot review their own submission. This is enforced in code, not
by convention, including when the author holds the reviewer role.

## 2. Content lifecycle

```
draft  ──submit──▶  community  ──reviewer approves──▶  verified
  ▲                     │                                  │
  └──changes requested──┘                                  │
                        └──reviewer rejects──▶ archived ◀───┘ (never deleted)
```

- **draft** — not public. Where automated moderation holds anything it flags.
- **community** — visible, badged "not yet verified", and **excluded from AI
  retrieval**. Being readable is not being authoritative.
- **verified** — authoritative. Shows the reviewer's name and review date, is
  citable, and is the only status the AI may retrieve.
- **archived** — withdrawn but retained. Content that fails moderation or review
  is archived, never silently deleted, so the trail stays intact.

## 3. What qualifies as verified

A reviewer may only approve content that meets **all** of the following:

1. **Every legal claim carries a citation** to a specific provision — a section,
   not a whole Act. Uncited assertions are rejected regardless of correctness.
2. **The citation resolves and supports the claim.** The reviewer opens the
   source and checks the text, rather than trusting the locator.
3. **Correct jurisdiction.** Only Nigerian primary sources are treated as
   authoritative law. General jurisprudence may inform wording but must never be
   presented as Nigerian law.
4. **Licensing is clean.** No proprietary law-report text — headnotes, editorial
   summaries, or report body text — is reproduced. Cases are cited and linked;
   digests must be our own words.
5. **Plain language.** Written for someone in distress, not for a lawyer.
6. **A review date is set.** See section 6.

Anything the automated screen flags as a possible proprietary copy **cannot be
approved at all** until the licensing flag is cleared. This is a hard block in
code, not a reviewer's judgement call.

## 4. Handling conflicting interpretations

Where the law is genuinely unsettled, the honest answer is to say so:

- State the majority or better-supported position, cite it, and note that the
  point is contested.
- Never present one side of a live dispute as settled law.
- Where authorities conflict, prefer the higher court and the more recent
  decision, and say which was preferred.
- If the conflict cannot be resolved responsibly in plain language, the content
  does not ship. A refusal is better than a confident wrong answer.

## 5. Error reports

- **Report-an-error is on every content and answer surface**, and is never gated
  behind an account. The reader most likely to spot wrong law is often the least
  likely to have signed up.
- Reports enter a triage queue, oldest first.
- Once a record reaches **3 open reports** it is automatically flagged for
  re-review and surfaced in the reviewer's flagged list.
- Every report and resolution is written to the audit log.

**Target: triage within 5 working days**; anything touching arrest, detention, or
personal safety is same-day.

## 6. Staleness

Law changes, and stale law is dangerous law.

- Every verified record carries a **`review_due_at`** date.
- When that date passes the record is **automatically dropped from AI
  retrieval** — it stops being answerable without anyone intervening. This is
  enforced in `is_retrievable()` and applies to rights topics, company
  obligations, and case digests alike.
- Stale records appear in the reviewer's queue at `/v1/review/stale`.
- Suggested cadence: **12 months** for constitutional rights content, **6 months**
  for company obligations, and **immediately on any amending legislation**.
  Company figures — filing deadlines, thresholds, penalties — move with finance
  legislation and are the most perishable content in the product.

## 7. Audit

Every submission, decision, error report, and resolution is written to an
append-only audit log recording the actor, the action, and the before/after
state. There is no update or delete path in the codebase, and a test asserts
that none is added. Administrators can read the trail; nobody can rewrite it.

## 8. Final sign-off

- A **qualified Nigerian lawyer** holds final sign-off on what may be marked
  verified. Engineering can ship the pipeline; it cannot grant the badge.
- The **lead legal editor** owns this policy and arbitrates conflicting
  interpretations under section 4.
- No content ships as verified on the strength of an AI draft, an engineer's
  reading, or a contributor's confidence.

## 9. Known gap

The seed content currently carries `status: verified` with
`reviewed_by: "Seed content (pending independent lawyer review)"`. That is a
contradiction: it is cited but **not** lawyer-reviewed, and it therefore does not
meet section 3. It must either be reviewed by a qualified Nigerian lawyer or have
its status lowered before any public launch.
