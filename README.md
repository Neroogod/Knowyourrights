# KnowYourRights

A trustworthy, offline-first app that helps people in Nigeria understand their
rights and know what to do in high-stress moments — grounded in the 1999
Constitution and other Nigerian law, with every claim cited or honestly refused.

> **North star:** robust, authentic, trustworthy — in that order, trust first.
> Wrong legal information is worse than none, so the whole system is built around
> one rule: **cite or refuse.** No answer is shown without a verifiable citation.

The full product vision lives in `../MVP.md` and the architecture plan; this
repository is the working implementation.

---

## Table of contents

- [What's here](#whats-here)
- [The three layers](#the-three-layers)
- [Trust guarantees](#trust-guarantees-by-design)
- [Repository layout](#repository-layout)
- [Quick start](#quick-start)
- [Content pipeline & the source report](#content-pipeline--the-source-report)
- [Running the API and web demo](#running-the-api-and-web-demo)
- [The mobile app](#the-mobile-app)
- [API overview](#api-overview)
- [PostgreSQL, migrations & content versioning](#postgresql-migrations--content-versioning)
- [AI / RAG](#ai--rag)
- [Trust & editorial operations](#trust--editorial-operations)
- [Monetization](#monetization)
- [Observability & operations](#observability--operations)
- [Privacy, retention & legal](#privacy-retention--legal)
- [Localization](#localization)
- [Testing & CI](#testing--ci)
- [Configuration](#configuration-environment-variables)
- [Honest limitations](#honest-limitations)

---

## What's here

| Area | Where | What it is |
|------|-------|-----------|
| **Content pipeline** | `content_pipeline/` | Parses statutes (PDF), preserves section locators, validates & builds `content_pack.json`, grades each source |
| **Verified content** | `content/` | 26 rights topics, 30 emergency scenarios, a directory, 3 CAMA obligations + a checklist, 6 case digests — all cited |
| **Backend API** | `backend/` | FastAPI service: reference, scenarios, directory, search, gated Q&A, accounts, custody alerts, trust ops, billing |
| **Grounded Q&A (RAG)** | `backend/rag/` | Retrieval over **verified content only** with a hard **cite-or-refuse** guarantee and an evaluation gate |
| **Mobile app** | `app/` | Flutter (iOS + Android), offline cache via drift, emergency-first design |
| **Web demo** | `web/` | The same surfaces in a browser, served by the API at `/` |
| **Design system** | `app/lib/theme.dart`, `widgets.dart` | Shared visual language (see below) |
| **Governance & ops** | `GOVERNANCE.md`, `OPERATIONS.md`, `legal/` | Editorial policy, runbooks, and legal drafts |

### Design system

Colour is **semantic and non-decorative**: **pine green** carries authority,
**brass** is used only for the Verified seal on lawyer-reviewed law, and **red**
is used only for danger and emergencies. Titles are set in a serif (the voice of
the law), constitutional locators such as `s.35(2)` in monospace (so citations
read as precise references), and the interface is emergency-first — the arrest
moment leads the home screen rather than hiding in a tab. Both clients support
light/dark themes, text scaling, and a high-contrast mode.

---

## The three layers

The same content engine serves three audiences; ~80% is shared.

- **Layer 1 — Individuals (B2C):** rights reference, emergency scenarios, a
  directory, and gated AI Q&A. Free and complete, forever.
- **Layer 2 — Companies (B2B):** obligations and compliance checklists grounded
  in **CAMA 2020**, with an entity-profile filter (`POST /v1/business/applicable`)
  that shows a business only the duties that bind it, plus a regulator directory.
- **Layer 3 — Law students:** a case-law library (facts / issues / holding /
  ratio + interpretations), study tools (saved cases, reading lists, filters), a
  citator graph, and a contribution pipeline.

---

## Trust guarantees (by design)

- Only `verified` content is indexed for Q&A; unverified/community content can
  never reach the AI.
- A non-refusal answer **must** include at least one citation — enforced in code
  and tested. The default answerer is *extractive* (no free-text generation), so
  hallucinated legal advice is structurally impossible; a hosted LLM can be
  swapped in behind the same guardrails.
- Content is validated on build: a `verified` record without a citation fails the
  build.
- **Staleness has teeth:** every citable record carries a `review_due_at`; once it
  passes, the record is automatically dropped from AI retrieval (`is_retrievable`).
- **Monetization never paywalls a right:** a plan only ever raises the AI question
  quota; rights, scenarios, the directory and Custody Alert are always free
  (enforced in `billing.py`, asserted by tests).
- **Jurisdiction guard:** only Nigerian primary sources are treated as
  authoritative; the three AI corpora (rights / company / students) are kept apart.

---

## Repository layout

```
knowyourrights/
  app/                     # Flutter mobile app (offline cache via drift)
    lib/
      main.dart            # screens + navigation
      theme.dart           # design tokens, light/dark, high-contrast
      widgets.dart         # shared trust components (Verified seal, citation chip, …)
      settings.dart        # appearance / accessibility / privacy settings
      api_client.dart      # content + Q&A, offline fallback, incognito
      account_client.dart  # auth, profile, custody alerts, students, billing
      offline_database*.dart, content_sync_client.dart
  backend/                 # FastAPI service (tested)
    api.py                 # all HTTP endpoints
    schemas.py             # content models + cite-or-refuse validators
    content_store.py       # in-memory store, filtering, answerers
    content_db.py          # PostgreSQL + pgvector repository
    content_sync.py, content_cli.py   # signed content packs, import CLI
    accounts.py            # auth, profiles, contacts, alerts, subscriptions
    account_schemas.py     # request/response models
    ai_ops.py              # AI gate: cache, quota, telemetry, privacy
    billing.py             # plans, entitlements, Paystack/Flutterwave
    review.py              # contribution → review → verified, moderation, audit log
    retention.py           # data-retention schedule + purge
    observability.py       # JSON logging, request IDs, Sentry
    delivery.py            # email/SMS gateways for custody alerts
    managed_auth.py        # optional Supabase auth
    rag/                   # answerer, embeddings, retrieval, pgvector, evaluate
    tests/                 # 165 pytest tests
  content_pipeline/        # ingestion: parse/section/chunk + build_pack (tested)
    sources.py             # registry of legal sources (jurisdiction, audience)
    sectioniser.py         # statute → numbered sections, with grading
    pdf_extract.py, chunker.py, build_pack.py
  content/                 # curated topics, scenarios, obligations, cases, directory
  data/sources/            # extracted source text (gitignored build artifact)
  migrations/              # Alembic migrations
  evaluations/             # RAG evaluation dataset + baseline
  legal/                   # DRAFT privacy/ToS/DPIA/retention/… (counsel review)
  web/                     # browser demo served at /
  Dockerfile, Procfile, render.yaml, fly.toml   # deployment
  GOVERNANCE.md, OPERATIONS.md, DEPLOY.md        # policy & runbooks
```

---

## Quick start

Requires Python 3.12+ and (for the app) Flutter.

```bash
cd knowyourrights
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

# Build the content pack (validates content + grades sources)
python content_pipeline/build_pack.py --run

# Run the API + web demo
uvicorn backend.api:create_app --factory --host 127.0.0.1 --port 8000
```

Then open <http://127.0.0.1:8000/> for the demo, or:

```bash
curl -s -X POST http://127.0.0.1:8000/v1/ask \
  -H 'Content-Type: application/json' \
  -d '{"question":"can the police search my phone?"}'
```

For account/onboarding testing without real email/SMS, run in development mode
(returns verification tokens in-band, uses a no-send delivery adapter and the
development payment gateway):

```bash
KYR_DEVELOPMENT_MODE=1 \
KYR_APP_SECRET="replace-with-32+-random-characters" \
uvicorn backend.api:create_app --factory --host 127.0.0.1 --port 8000
```

---

## Content pipeline & the source report

`build_pack.py --run` validates every record, writes `data/content_pack.json`,
then extracts, **sections, and grades** each legal source registered in
`content_pipeline/sources.py`. It prints a source report, because a damaged
document is the quietest way to break a citation:

```
constitution-1999     273 sections   85% coverage  DEGRADED (probe) - s.35 lacks 'personal liberty'
interpretation-act     39 sections   98% coverage  citable
cama-2020             870 sections  100% coverage  citable
ndpa-2023              16 sections   25% coverage  DEGRADED (coverage)
```

A source is **citable** only if it parses ≥80% of its sections **and** its probes
land the expected text on the expected locator — the second check catches a
document that parses but attaches the wrong body to a locator (which still looks
like a valid citation). **CAMA 2020 parses completely**; the current NDPA copy and
Constitution PDF are degraded and are not cited from parsed text until replaced.

Shipped citations are unaffected: they are **hand-authored and cited**, not parsed.

### Authoring content

Add a JSON file under `content/<type>/`. A record with `"status": "verified"`
must include at least one citation and a `reviewed_by` value, or the build rejects
it. Scenario steps may carry `"action": "call"` with a `value`:

| `value` | Button behaviour |
|---------|------------------|
| `emergency_line` | Dials **112** (red button) |
| `lawyer` | Opens the dialer to call your lawyer |
| `trusted_contact` | Opens the dialer to call someone you trust |
| a directory id / type | Dials that contact, or opens its website |

---

## Running the API and web demo

```bash
uvicorn backend.api:create_app --factory --host 127.0.0.1 --port 8000
# demo at /  · health at /v1/health
```

To enable grounded generative answers, supply an API key **to the backend only**:

```bash
OPENAI_API_KEY=... KYR_OPENAI_MODEL=gpt-5.6-terra \
uvicorn backend.api:create_app --factory --host 127.0.0.1 --port 8000
```

Without a key, every Ask surface uses the local extractive cite-or-refuse
answerer. AI generation is server-side only; credentials and safety/profile data
never enter the clients' prompts.

---

## The mobile app

```bash
cd app
flutter pub get
flutter run                                                   # deployed API by default
flutter run --dart-define=KYR_BASE_URL=http://127.0.0.1:8000  # against a local backend
```

Screens: emergency-first **Home**, **Rights** (+ topic detail), **Emergencies**
(+ scenario detail with one-tap call), **Ask**, **Company**, **Students** (case
library), **Get help** (directory), **Custody Alert**, and **Settings**
(theme, text size, high contrast, incognito, notifications, language). Content and
emergency scenarios are cached for **offline** use; the app falls back to an
offline cite-or-refuse answer with no connection.

Checks: `flutter analyze`, `flutter test`. Neither catches render-time failures —
run on a device or simulator before trusting a UI change.

---

## API overview

REST/JSON over HTTPS, versioned under `/v1`. Errors use a structured envelope
`{"error": {"code", "message", "details"}}` while retaining a plain `detail`
field for older clients. Reviewer/admin endpoints are role-gated.

| Group | Endpoints (representative) |
|-------|----------------------------|
| Content | `GET /v1/topics` (filters: category, jurisdiction, status), `/v1/topics/{id}`, `/v1/categories`, `/v1/scenarios`, `/v1/search` |
| Q&A | `POST /v1/ask?audience=individual\|business\|student` (+ `/ask/stream`), `POST /v1/company/ask`, `POST /v1/students/ask` — incognito via `X-KYR-Incognito` |
| Directory | `GET /v1/directory` (type, state, lga, specialty, near), `/v1/directory/filters`, `POST /v1/directory/contributions` |
| Company | `GET /v1/company/obligations`, `/checklists`, `/regulators`, `POST /v1/business/applicable` |
| Students | `/v1/students/cases` (area/court/year), `/filters`, `/{id}/related`, saved cases, reading-lists, preferences, `POST …/interpretations`, `/digests` |
| Accounts | `/v1/auth/*`, `/v1/profile`, `/v1/account` (export, delete, sessions), `/v1/sync` |
| Custody Alert | `/v1/custody-alerts` (+ cancel/resolve/retry), `/check-ins`, `/public/custody-alerts/{token}` |
| Trust ops | `POST /v1/contributions`, `/v1/review/*`, `/v1/error-reports`, `/v1/admin/audit-log` |
| Billing | `GET /v1/billing/plans`, `/subscription`, `POST /v1/billing/checkout`, `/webhook/{provider}` |
| Observability | `GET /v1/admin/metrics/{content-health,ai,trust-kpis}` |
| Sync | `GET /v1/content-pack`, `GET /v1/content-packs/{layer}` (signed delta) |

~93 endpoints in total. Full schema is auto-generated by FastAPI at `/docs`.

---

## PostgreSQL, migrations & content versioning

The MVP serves the built JSON pack and retrieves with a dependency-free TF-IDF
index, so it runs with no database. Production uses **PostgreSQL + pgvector**;
Alembic is the only schema writer (the app never calls `create_all()` against
Postgres).

```bash
# Apply migrations before starting app processes (gated deploy step)
DATABASE_URL=postgresql+psycopg://... alembic upgrade head

# Import the validated content pack as a new immutable version
DATABASE_URL=... python -m backend.content_cli import --file data/content_pack.json

# Generate / refresh embeddings for verified chunks
DATABASE_URL=... KYR_EMBEDDING_PROVIDER=local KYR_EMBEDDING_MODEL=BAAI/bge-m3 \
  python -m backend.content_cli reembed
```

Changing the pack creates a new version and atomically marks it active; importing
an identical checksum is idempotent; previous versions remain for audit and
rollback.

---

## AI / RAG

- **Retrieval:** hybrid (vector + keyword) over **verified chunks only**, filtered
  by status and jurisdiction, with a minimum similarity threshold; below it, the
  answer refuses.
- **Guardrails:** every answer must resolve ≥1 valid citation to a retrieved
  chunk or it is suppressed and the refusal UI shown; the "information, not
  advice" disclaimer is always appended.
- **Production gate:** production AI is blocked until every verified chunk is
  embedded with the configured model; a curated legal QA evaluation
  (`backend/rag/evaluate.py`, dataset in `evaluations/`) must clear accuracy,
  citation-validity and refusal-correctness thresholds — and not regress from the
  baseline — before AI ships. This runs in CI.
- **Tiered quota:** free 5/day, premium/student 100/day, team 500/day (see
  [Monetization](#monetization)); incognito requests are neither cached nor logged.

---

## Trust & editorial operations

The pipeline behind the Verified badge (`backend/review.py`, policy in
`GOVERNANCE.md`):

```
draft ──submit──▶ community ──reviewer approves──▶ verified
  ▲                   │                                │
  └──changes──────────┘        ┌──reviewer rejects──▶ archived (never deleted)
```

- **Roles:** reader → contributor → reviewer (lawyer/editor) → administrator.
- A contributor **cannot review their own submission** (enforced in code).
- **Moderation** screens for missing citations, near-duplicates, and pasted
  proprietary law-report text (a hard block on verification).
- **Report-an-error** is on every content and answer surface, never gated behind
  an account; enough open reports auto-flag a record for re-review.
- **Append-only audit log** of every decision; no update or delete path exists (a
  test asserts none is added).

---

## Monetization

Plans (`backend/billing.py`) only ever change the **AI question quota** — never
content access:

| Plan | AI questions/day |
|------|------------------|
| Free (default, incl. anonymous) | 5 |
| Premium / Student | 100 |
| Team | 500 |

Payments use a provider-agnostic gateway with **Paystack** and **Flutterwave**
adapters (Nigerian rails) plus a development adapter. Webhook signatures are
verified; a webhook for a reference we never issued grants nothing; activation is
idempotent. Live payments require real merchant keys — without them the adapters
fail closed. Org seats, campus licences, and the lawyer referral marketplace are
deferred (see `GOVERNANCE.md` §14).

---

## Observability & operations

- **Structured JSON logs** (`backend/observability.py`), one per request, with a
  **request id** echoed as `X-Request-ID`; query strings are never logged.
- **Sentry** initialises only when `SENTRY_DSN` is set (no-op otherwise).
- **Dashboards** (reviewer/admin, computed on demand, no prompts retained):
  `content-health`, `ai` (cost/latency/refusal), `trust-kpis`.
- **CI/CD, backup/restore drill, and a disaster-recovery runbook** are documented
  in `OPERATIONS.md`.

---

## Privacy, retention & legal

- **Data-retention schedule** (`backend/retention.py`) is the single source of
  truth, enforced by an hourly purge job — location is purged at incident close;
  telemetry, cache, tokens and webhook events age out; the audit log and versioned
  content are intentionally exempt. Mirrored in `legal/RETENTION-SCHEDULE.md`.
- **Encryption:** profile, contact, and custody-alert location fields are
  encrypted at rest; TLS in transit.
- **`legal/`** holds DRAFT documents — Privacy Policy, Terms, Disclaimer, a
  Custody Alert **DPIA**, Record of Processing, data-subject-rights procedure,
  app-store privacy declarations, contributor agreement, and a source-provenance
  register. **All require counsel/DPO review before publication** (see
  `legal/README.md` for the decisions a person must make).

---

## Localization

Content records carry `language`, `translation_of`, and `source_hash` fields;
`translation_is_stale()` flags a translation the moment its source text drifts, so
a stale translation cannot pose as current law. Translations flow through the same
review pipeline. UI strings are externalised behind a `t()` layer with a language
selector; **English is complete; Nigerian Pidgin, Hausa, Yoruba and Igbo are
registered and marked in progress** — real translations are human work, done
through the review workflow, not machine-generated.

---

## Testing & CI

```bash
# Backend: pytest + coverage floor (≥70%)
python -m pytest -q --cov

# Runnable module self-tests (the pipeline's tested hybrid strategy)
python content_pipeline/sectioniser.py
python backend/billing.py
python backend/retention.py

# Lint & format
ruff check .
ruff format --check .

# App
cd app && flutter analyze && flutter test
```

`.github/workflows/ci.yml` runs on every PR and push: lint, format, tests +
coverage, a `pip-audit` security scan, the pipeline self-tests, a **migration
gate** (upgrade/downgrade/upgrade + single-head check), the **AI trust gate**, and
Flutter analyze/test. **165 backend tests + Flutter tests** currently pass.

---

## Configuration (environment variables)

| Variable | Purpose |
|----------|---------|
| `KYR_APP_SECRET` | **Required.** Signs tokens; keys encrypted profile/contact/location fields |
| `DATABASE_URL` | PostgreSQL DSN in production; SQLite by default for local dev |
| `KYR_DEVELOPMENT_MODE=1` | No-send delivery + dev payment gateway; returns verification tokens in-band |
| `OPENAI_API_KEY`, `KYR_OPENAI_MODEL` | Enable grounded generative answers (optional) |
| `KYR_AI_PRODUCTION_ENABLED`, `KYR_EMBEDDING_*` | Production RAG over pgvector |
| `RESEND_API_KEY`, `KYR_EMAIL_FROM`, `TWILIO_*` | Production email/SMS for custody alerts |
| `PAYSTACK_SECRET_KEY` / `FLUTTERWAVE_*`, `KYR_BILLING_CALLBACK_URL` | Live payments |
| `SENTRY_DSN` | Error tracking (optional) |
| `KYR_PUBLIC_BASE_URL`, `KYR_LOG_LEVEL`, `KYR_AI_DAILY_QUOTA` | Misc |

See `DEPLOY.md` for deployment (Render/Fly/Docker) and `OPERATIONS.md` for the
staging→production process.

---

## Honest limitations

- **Seed content is cited but not yet independently lawyer-reviewed** — it is
  marked "pending independent lawyer review" and must be reviewed by a qualified
  Nigerian lawyer before launch. `GOVERNANCE.md` §9 records this contradiction in
  the current `verified` status.
- **Directory phone numbers are mostly empty** — only national emergency lines
  (112, FRSC 122) are present; real legal-aid numbers are a pre-launch content
  task, and none are fabricated.
- **NDPA 2023 and the Constitution PDF parse poorly** — cleaner official copies
  are needed before citing from parsed statute text (see the source report).
- **Custody Alert, live payments, org accounts/seats, notification delivery, and
  the Nigerian-language translations** are specified and partly scaffolded but not
  fully implemented — see `GOVERNANCE.md` and `legal/` for what is deferred and why.

---

Licensing of source materials (NOUN course, NWLR reports) and provenance sign-off
are tracked in `legal/SourceProvenance.md`. Editorial policy and what qualifies as
verified are in `GOVERNANCE.md`.
