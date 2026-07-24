# KnowYourRights (MVP)

A trustworthy, offline-first app that helps people in Nigeria know their rights and what to
do in high-stress moments, grounded in the 1999 Constitution. This repository implements the
MVP slice described in `../MVP.md`.

## What is built

- **Content pipeline** (`content_pipeline/`) - parses the Constitution PDF, chunks text, and
  builds a validated `content_pack.json` from authored, cited content.
- **Verified content** (`content/`) - lawyer-reviewable rights topics and emergency scenarios,
  every one carrying citations to specific constitutional provisions.
- **Backend API** (`backend/`) - FastAPI service for reference, scenarios, directory, search,
  and a gated Q&A endpoint.
- **Grounded AI Q&A** (`backend/rag/`) - retrieval over **verified content only** with a hard
  **cite-or-refuse** guarantee. With `OPENAI_API_KEY` configured, the backend uses the Responses
  API to explain retrieved evidence in clearer language. The model may select only stored source
  IDs; the backend resolves those IDs to citations and rejects invented or missing sources. With
  no key—or whenever generation or validation fails—the deterministic extractive answerer is used.
- **Mobile app** (`app/`) - the Flutter client (iOS + Android). Loads the content pack, caches
  it for offline use, and falls back to an offline cite-or-refuse answer when there is no
  network. First launch is account-gated: verified email, personal profile, and a verified
  emergency contact are required before the main app opens. Screens: emergency-first Home,
  Rights (+ topic detail), Emergencies (+ scenario detail), Ask, Company, Students
  (case-law library), and Get help.
- **Web demo** (`web/`) - the same surfaces in a browser, served by the API at `/`.
- **Design system** (`app/lib/theme.dart`, `app/lib/widgets.dart`) - shared by app and web.
  Colour is semantic and non-decorative: **pine green** carries authority, **brass** is used
  only for the Verified seal on lawyer-reviewed law, and **red** is used only for danger and
  emergencies. Titles are set in a serif (the voice of the law) and constitutional locators
  such as `s.35(2)` in monospace, so citations read as precise references.

## Trust guarantees (by design)

- Only `verified` content is indexed for Q&A; unverified/community content can never reach it.
- A non-refusal answer must include at least one citation (enforced in code and tested).
- Generated answers can cite only source IDs present in the retrieved verified evidence.
- AI generation is server-side only; credentials and personal safety/profile data never enter
  the Flutter or web clients' prompts.
- A persistent "information, not advice" disclaimer is attached to every answer.
- Content is validated on build: a `verified` topic without a citation fails the build.

## Setup

```bash
cd knowyourrights
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
```

## Build the content pack

```bash
python content_pipeline/build_pack.py --run
```

This validates all content, writes `data/content_pack.json`, then extracts every legal
source registered in `content_pipeline/sources.py` to `data/sources/<source-id>.txt`,
splits each into numbered sections, and grades it.

The build prints a source report, because a damaged document is the quietest way to break
a citation:

```
constitution-1999     273 sections   85% coverage  DEGRADED (probe) - s.35 lacks 'personal liberty'
interpretation-act     39 sections   98% coverage  citable
cama-2020             870 sections  100% coverage  citable
ndpa-2023              16 sections   25% coverage  DEGRADED (coverage)
```

A source is **citable** only if it parses at least 80% of its known sections *and* its
probes land the expected text on the expected locator. The second check matters more than
the first: a document can parse most of its sections while attaching the wrong body to a
locator, and that failure still looks like a valid citation.

Current state: **CAMA 2020 parses completely** and grounds the starter Companies slice:
three draft obligations and a first-year checklist are included in the offline pack and
served at `/v1/company/obligations` and `/v1/company/checklists`. The **Students** slice
ships six educational case digests (facts / issues / holding / ratio + study notes) at
`/v1/students/cases` and `/v1/students/ask`. Digests are original study notes that cite
case name + court/year and link out to licensed reports — proprietary NWLR text is not
copied. The **NDPA 2023** copy
has a damaged text layer (25%), and this **Constitution** PDF loses
inline numbering in Chapter IV so bodies misattach to locators — both need cleaner
documents before anything is cited from parsed text. Shipped rights citations are
unaffected: they are hand-authored and lawyer-checked, not parsed.

## Run the API + demo

```bash
uvicorn backend.api:create_app --factory --host 127.0.0.1 --port 8000
```

To enable grounded AI answers, supply the API key only to the backend:

```bash
OPENAI_API_KEY=your-server-side-key \
KYR_OPENAI_MODEL=gpt-5.6-terra \
uvicorn backend.api:create_app --factory --host 127.0.0.1 --port 8000
```

`KYR_OPENAI_MODEL` is optional. Without `OPENAI_API_KEY`, all Ask screens continue to use the
local extractive cite-or-refuse implementation. Custody Alert, SMS, location sharing, account
profiles, and emergency contacts never use the AI answerer.

For local account/onboarding testing, enable the non-sending delivery adapter. Verification
tokens are returned only in this mode, allowing the Flutter setup flow to complete without
contacting real email addresses or phone numbers:

```bash
KYR_DEVELOPMENT_MODE=1 \
KYR_APP_SECRET=replace-this-with-at-least-32-random-characters \
uvicorn backend.api:create_app --factory --host 127.0.0.1 --port 8000
```

Account data uses SQLite at `data/accounts.db` locally. Set `DATABASE_URL` to PostgreSQL in
production. `KYR_APP_SECRET` protects access tokens and encrypted profile/contact/location
fields and must come from the deployment secret store. The development adapter records
email/SMS attempts in memory and never sends them. Production delivery uses **Resend** for
transactional email and **Twilio** for SMS, and fails closed if a required setting is absent:

## PostgreSQL content and migrations

Production uses Alembic as the only schema writer. Application startup never calls
`create_all()` against PostgreSQL. The initial revision creates account tables plus normalized,
versioned content tables for categories, sources, citations, topics, scenarios, obligations,
checklists, cases, directory entries, chunks, and embedding-model history. It also enables
`pgvector`, creates a filtered HNSW cosine index for verified chunks, and adds PostgreSQL GIN
full-text indexes.

Run schema migrations before deploying application processes:

```bash
DATABASE_URL=postgresql+psycopg://... alembic upgrade head
```

Import the validated content pack as a new immutable version:

```bash
DATABASE_URL=postgresql+psycopg://... \
python -m backend.content_cli import --file data/content_pack.json
```

Changing the pack creates a new version and atomically marks it active; importing an identical
checksum is idempotent. Previous versions remain available for audit and rollback. To generate
embeddings for verified chunks, or re-embed after changing the configured model/version:

```bash
DATABASE_URL=postgresql+psycopg://... \
KYR_EMBEDDING_PROVIDER=local \
KYR_EMBEDDING_MODEL=BAAI/bge-m3 \
KYR_EMBEDDING_MODEL_VERSION=main \
python -m backend.content_cli reembed
```

The default provider is local BGE-M3, producing normalized 1,024-dimensional embeddings without
an API key. Set `KYR_EMBEDDING_PROVIDER=openai` and configure `OPENAI_API_KEY` only if a hosted
embedding provider is preferred. Enable database-backed API content with
`KYR_CONTENT_BACKEND=database`. If the configured embedding runtime is available, Q&A retrieval
uses pgvector; otherwise it retains the offline TF-IDF fallback. `KYR_CONTENT_AUTO_IMPORT=1` is
intended only for a brand-new environment. Production imports are explicit release steps.

Migration policy:

- Generate revisions with `alembic revision --autogenerate`, then review SQL in CI.
- Test both an empty-database upgrade and content imports before release.
- Prefer expand/migrate/contract changes; deploy compatible code before destructive schema work.
- Back up before destructive migrations. Production rollback is an explicit operator decision.
- Changing the embedding model or version creates a tracked model record and queues every active
  verified chunk whose stored model does not match.

```bash
KYR_APP_SECRET=replace-with-a-long-random-secret \
KYR_PUBLIC_BASE_URL=https://your-public-app.example \
RESEND_API_KEY=re_... \
KYR_EMAIL_FROM='Know Your Rights <safety@your-verified-domain.example>' \
TWILIO_ACCOUNT_SID=AC... \
TWILIO_AUTH_TOKEN=... \
TWILIO_FROM=+1... \
KYR_DELIVERY_WEBHOOK_SECRET=replace-with-a-separate-random-secret \
DATABASE_URL=postgresql+psycopg://... \
uvicorn backend.api:create_app --factory --host 0.0.0.0 --port 8000
```

Use restricted production credentials and deployment secrets; never commit them. `TWILIO_FROM`
must be a sender capable of reaching the contact's country. Provider acceptance marks an alert
`sent`; it becomes `delivered` only after a signature-verified Twilio callback. Rejection marks it
`failed`, allowing the client to open its device-SMS fallback. Failed relay attempts retry in the
background with bounded exponential backoff. Users can cancel false alarms or mark an incident
resolved, and precise coordinates are purged after 24 hours by the retention worker.

### Managed authentication decision: Supabase Auth

Supabase Auth is the production identity provider. It was selected over Auth0 because this product
also needs PostgreSQL-backed profiles, emergency contacts, roles, and row-level authorization.
FastAPI remains the resource server and verifies Supabase access tokens against the project's JWKS.
The legacy FastAPI password endpoints remain available only when `SUPABASE_URL` is absent, so local
tests and a controlled migration of existing development accounts remain possible.

Apply [the Supabase migration](supabase/migrations/202607230001_managed_auth.sql), then:

1. Enable email/password authentication, email confirmation, Secure Email Change, refresh-token
   reuse detection, and leaked-password protection in Supabase Auth.
2. Add `knowyourrights://auth/callback`, `knowyourrights://auth/reset`, and the production web URL
   to Auth redirect URLs.
3. Enable `public.custom_access_token_hook` as the Custom Access Token Hook.
4. Configure an asymmetric JWT signing key and keep access-token lifetime at 5–60 minutes.
5. Store `SUPABASE_SECRET_KEY` only on the FastAPI server.

Run the API with `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `SUPABASE_SECRET_KEY`. Build mobile
with public values only:

```bash
flutter run \
  --dart-define=KYR_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_REPLACE_ME
```

Supabase owns PKCE sessions, one-time refresh-token rotation, verification, recovery, secure email
change, and scoped sign-out. The application adds a device inventory and resource-server session
revocation, recent-password confirmation for email change/export/deletion, account export and
deletion, roles (`reader`, `contributor`, `reviewer`, `administrator`), and IP/device/user/contact
abuse limits persisted in the shared application database.

### Custody Alert reliability

Custody Alert supports one to three verified contacts and fans an intentional alert out to all of
them. Each contact invitation contains independent Confirm, Decline, and one-year withdrawal
capability links. A test-alert action uses the explicit `TEST CUSTODY ALERT — NO EMERGENCY` prefix.
Optional station names, location, timestamp, and an unguessable tracking URL are included in the
message. The public tracking page shows current status and verified next steps without requiring an
account; the capability token is hashed for lookup and encrypted at rest.

Delivery is recorded independently for gateway SMS, WhatsApp, email, and push. SMS uses Twilio,
email uses Resend, WhatsApp uses `TWILIO_WHATSAPP_FROM`, and push uses a server-to-server worker
configured by `KYR_PUSH_WEBHOOK_URL` and `KYR_PUSH_WEBHOOK_SECRET`. Provider callbacks require
signatures and are replay-deduplicated. Failed deliveries use bounded exponential retry and the
mobile client keeps a durable idempotent queue when it cannot reach the API.

Android can request `SEND_SMS` at the moment an intentionally triggered alert needs its offline
fallback and send directly after permission is granted. This sensitive permission must be declared
and justified during Play review. iOS cannot send silently and therefore opens a pre-addressed
Messages composer. Both platforms expose Custody Alert and Safe Walk through app-icon quick
actions.

Safe Walk is a server-owned dead-man timer. The user chooses a check-in period and taps “I'm safe”
to stop it. If the deadline passes, the backend worker creates idempotent alerts for every verified
contact even if the initiating phone is subsequently offline or seized.

Then open http://127.0.0.1:8000/ for the demo, or call the API:

```bash
curl -s -X POST http://127.0.0.1:8000/v1/ask \
  -H 'Content-Type: application/json' \
  -d '{"question":"can the police search my phone?"}'
```

### Key endpoints

- `GET /v1/health`
- `GET /v1/topics` / `GET /v1/topics/{id}`
- `GET /v1/scenarios` / `GET /v1/scenarios/{id}`
- `GET /v1/directory`
- `GET /v1/search?q=...`
- `POST /v1/ask` (body: `{"question": "..."}`)
- `GET /v1/content-pack` (full pack for offline caching)
- `GET /v1/content-packs/config` (content-signing key and supported layers)
- `GET /v1/content-packs/{rights|students|company}?since=...&jurisdiction=...`
  (signed, version-aware packs with ETag/304 support)
- `GET/POST /v1/sync` (authenticated saved-content and draft synchronization)
- `GET /v1/company/obligations` / `GET /v1/company/checklists` / `POST /v1/company/ask`
- `GET /v1/students/cases` / `GET /v1/students/cases/{id}` / `POST /v1/students/ask`
- `POST /v1/auth/register`, `/v1/auth/login`, `/v1/auth/forgot-password`,
  `/v1/auth/reset-password`
- `GET/PUT /v1/profile`
- `GET/POST /v1/emergency-contacts`
- `POST /v1/custody-alerts`

### Mobile offline architecture

The Flutter app stores typed content, sync state, alert jobs, saved items, drafts, and an
encrypted emergency-contact cache in a Drift/SQLite database. Rights, student, and company
content are downloaded separately for the selected jurisdiction. Every downloaded pack is
verified with Ed25519 and SHA-256 before one database transaction makes it visible; invalid or
partial downloads leave the last verified pack untouched.

Requests send both `since=<content version>` and `If-None-Match`; unchanged layers receive a
304 response. Custody alerts created without a connection retain one stable idempotency key,
retry with backoff when connectivity returns, and remain safe to submit more than once.
The More screen reports offline availability separately for rights, student content, company
content, emergency contacts, custody alerts, saved content, and drafts.

## Testing

The project follows a hybrid strategy (see `code/SKILL.md`):

- **Pure modules** carry runnable `__main__` assert-tests:
  ```bash
  python content_pipeline/chunker.py
  python backend/rag/embeddings.py
  python backend/rag/answerer.py
  ```
- **Integration/API** use pytest:
  ```bash
  python -m pytest -q
  ```
- **Lint:** `ruff check .`

## Content authoring

Add a topic JSON to `content/topics/` or a scenario to `content/scenarios/`. A record with
`"status": "verified"` must include at least one citation and a `reviewed_by` value, or the
build will reject it. Re-run the build to publish.

### Scenario step actions (content ↔ app contract)

A scenario step may carry `"action": "call"` with a `value` the clients turn into a one-tap
call button. The following semantic values are built in:

| `value` | What the button does |
|---------|----------------------|
| `emergency_line` | Dials **112**, the national emergency line. Rendered in red. |
| `lawyer` | Opens the dialer for the user to call their lawyer. |
| `trusted_contact` | Opens the dialer for the user to call someone they trust. |

The value may also be a directory entry id (for example, `nhrc`) or entry type (for example,
`legal_aid`). The app uses the matching entry's phone number when available, otherwise its
website, and finally a named empty-dialer fallback. Unknown values use a generic "Call"
button. A step with `"action": "link"` opens its `value` as a URL.

`linked_topic_ids` must reference topic ids that exist, or the link is silently dropped.

## Running the mobile app

```bash
cd app
flutter pub get
flutter run                                     # uses the deployed API by default
flutter run --dart-define=KYR_BASE_URL=http://127.0.0.1:8000   # against a local backend
```

Checks: `flutter analyze` and `flutter test`. Note that neither catches render-time
failures, so run the app on a device or simulator before trusting a UI change.

## Notes and honest limitations

- Seed content is transcribed and cited from the 1999 Constitution but is marked
  "pending independent lawyer review"; it must be reviewed by a qualified Nigerian lawyer
  before any real launch.
- The offline retrieval uses a dependency-free TF-IDF embedder so the MVP runs without API
  keys. Swap in a hosted embedding/LLM provider via the `Embedder`/`Answerer` interfaces for
  higher answer quality, keeping the cite-or-refuse guardrails.
- The Postgres/pgvector backing store described in `../MVP.md` is not built: the MVP serves
  the content pack from the built JSON and retrieves with a dependency-free TF-IDF index.
- **Custody Alert** includes verified email onboarding, password reset, an encrypted personal
  profile, affirmative emergency-contact verification, foreground location capture, idempotent
  server relay, Resend/Twilio production delivery, provider-failure status, and the device SMS
  fallback. Valid provider accounts, approved senders, credentials, and real-device acceptance
  testing are still required before emergency use.
- **Directory phone numbers are mostly empty.** Only the national emergency lines (112, and
  FRSC 122) are present; the legal-aid entries carry official URLs but no numbers, because
  inventing contact details would break the same trust guarantee the citations protect. Real
  numbers must be added before launch.
- **Companies (Layer 2) is a starter slice.** The content schema, offline pack, API, and
  Flutter Companies screen are integrated with three CAMA-grounded obligations and one
  checklist. The entries remain drafts until a Nigerian company-law practitioner reviews
  them. A separate CAMA-only cite-or-refuse Q&A path is wired into the API, Flutter app,
  and web demo; it excludes every draft until lawyer review. Deadlines/reminders and NDPA
  obligations are not built because the available NDPA 2023 source copy is too degraded
  to cite safely.
