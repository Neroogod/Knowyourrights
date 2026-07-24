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

## 10. Student contributions

Law students may contribute case digests and interpretations. The same rules
apply, with two additions specific to this layer:

- **Digests must be the student's own words.** Reproducing a law report's
  headnote or body text is the licensing risk this product cannot take, and the
  automated screen blocks it before a reviewer ever sees it.
- **Citator relations are legal claims.** Asserting that one case *overrules*,
  *distinguishes*, *follows*, or *cites* another is an assertion about the law
  and is reviewed like any other content. Relations default to `draft` and are
  shown as "pending review" until verified.

Accepted contributions are attributed to their author, and a contributor's
record is visible to them at `/v1/students/me/contributions`. Contribution is a
route into reviewer training, not free labour.

## 11. Company layer — status and what gates the rest

The company **engine** is built: an entity profile (type, staff, sector, state,
turnover) filters obligations via `POST /v1/business/applicable`, obligations
carry structured applicability plus frequency, deadline, and consequence fields,
and the regulator directory (CAC, FIRS, NDPC, PenCom, NSITF, ITF) links to
official `.gov.ng` sites. This works in both the web and Flutter clients.

What it is **not** yet, and why:

- **Only three CAMA obligations exist, all `draft`.** Deadlines, thresholds, and
  penalty figures are the highest-risk facts in the product, so they are written
  conservatively and cited to a section, never invented. Nothing here is
  answerable by the AI until a reviewer verifies it (section 6).
- **NDPA, Labour Act, tax (CITA/PITA/VAT/FIRS), pension, ITF and NSITF content
  do not exist.** Authoring them needs the statutes ingested and a lawyer — and,
  for tax and accounting duties, an accountant's sign-off. The NDPA copy on file
  parses at only 25% (see the source report), so even data-protection
  obligations wait on a clean document.
- **Mandatory review-due dates** are supported (`review_due_at` drops stale
  content from retrieval, section 6) but must be set per obligation during
  review, using the cadence in section 6.

Deliberately **deferred** (a business decision, not a missing feature):
organization accounts, member and seat management, subscriptions, team AI limits,
and the compliance export/audit dashboard. Consistent with section 4c of the
build plan, the compliance content ships free and anonymous first; accounts and
billing follow once the content has proven its worth. Building seats before the
content is verified would sell access to material no lawyer has checked.

## 12. Directory depth

The directory now filters by type, state, LGA, and specialty, and sorts
location-aware: a `near` state floats local help — then nationwide (Federal)
bodies — to the top, but never drops an entry, because a lawyer two states away
still beats none.

Entries carry LGA, email, address, and specialty. Regulators (section 11) are a
directory type. Community members can suggest a legal-aid contact or a correction
via the contribution flow; a submitted entry is `community` (visible-but-badged
elsewhere, not shown live in the shipped directory) until an editor confirms it,
exactly like every other contribution. A directory entry is a contact, not a
legal claim, so it is exempt from the citation requirement — but not from the
proprietary-text and duplicate checks, and not from review.

Still needed before launch: real per-state legal-aid contacts. The shipped
directory is a national seed; the value of location filtering grows with the
number of state and LGA entries a lawyer has verified.

## 13. General user features & API contract — status

Built this pass:
- **API contract:** `GET /v1/categories` (with counts + ETag); jurisdiction and
  status filters on `/v1/topics`; a unified `POST /v1/ask?audience=` that routes
  to the individual, business, or student corpus (kept apart so one never answers
  from another); and a structured error envelope `{error:{code,message,details}}`
  added **additively** — the plain `detail` field older clients read is retained.
- **Incognito Ask:** an `X-KYR-Incognito` header runs a question with no cache and
  no telemetry, so a sensitive query leaves no trace. The hourly rate limit still
  applies, so it is not an abuse bypass.
- **General features:** reading history, saved topics, and notification/privacy
  preferences ride the existing per-user sync store (so they survive a reinstall);
  a web **Settings** surface with theme, **text-size** and **high-contrast**
  accessibility controls, an incognito toggle, a legal-change-notification
  preference, data export, and account deletion.

Already present before this pass (listed as "missing" but in fact built):
contributions, reviews, error reports, interpretation submission,
entity-applicability, full directory filters, alert cancellation/resolution,
delivery callbacks, check-in endpoints, the public alert status page, signed/delta
content-pack endpoints, data export, and account deletion.

Deferred, with reasons:
- **Cursor pagination and broad ETag on list reads:** premature on a corpus of
  ~26 topics and 6 cases, and switching list responses to a paginated envelope
  would break both shipped clients. Add when a corpus is large enough to need it.
- **Legal-change notifications (delivery):** the *preference* and the staleness
  signal exist; actually pushing a notification needs push infrastructure (APNs/
  FCM) and a job that diffs content versions — a separate build.
- **Flutter settings/accessibility parity:** the web got the Settings surface this
  pass; the Flutter app already honours system text scaling and theme, but an
  explicit in-app settings screen is follow-up.
- **Organizations, memberships, subscriptions, billing webhooks:** a Layer 2
  business decision, deferred until the content is verified and proven (section 11).
