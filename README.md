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
- **Grounded Q&A** (`backend/rag/`) - retrieval over **verified content only** with a hard
  **cite-or-refuse** guarantee: an answer is either backed by a citation or it refuses. The
  default answerer is extractive (no free-text generation), so hallucinated legal advice is
  structurally impossible. The `Answerer`/`Embedder` interfaces let a hosted LLM be swapped in
  later without changing callers.
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

```bash
KYR_APP_SECRET=replace-with-a-long-random-secret \
KYR_PUBLIC_BASE_URL=https://your-public-app.example \
RESEND_API_KEY=re_... \
KYR_EMAIL_FROM='Know Your Rights <safety@your-verified-domain.example>' \
TWILIO_ACCOUNT_SID=AC... \
TWILIO_AUTH_TOKEN=... \
TWILIO_FROM=+1... \
DATABASE_URL=postgresql+psycopg://... \
uvicorn backend.api:create_app --factory --host 0.0.0.0 --port 8000
```

Use restricted production credentials and deployment secrets; never commit them. `TWILIO_FROM`
must be a sender capable of reaching the contact's country. Provider acceptance marks an alert
`sent`; rejection marks it `failed`, allowing the client to open its device-SMS fallback.

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
- `GET /v1/company/obligations` / `GET /v1/company/checklists` / `POST /v1/company/ask`
- `GET /v1/students/cases` / `GET /v1/students/cases/{id}` / `POST /v1/students/ask`
- `POST /v1/auth/register`, `/v1/auth/login`, `/v1/auth/forgot-password`,
  `/v1/auth/reset-password`
- `GET/PUT /v1/profile`
- `GET/POST /v1/emergency-contacts`
- `POST /v1/custody-alerts`

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
