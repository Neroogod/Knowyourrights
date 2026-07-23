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
- **Web demo** (`web/`) - a simple UI to try the MVP in a browser.

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

Current state: **CAMA 2020 parses completely** and is ready to ground company content. The
**NDPA 2023** copy has a damaged text layer (25%), and this **Constitution** PDF loses
inline numbering in Chapter IV so bodies misattach to locators — both need cleaner
documents before anything is cited from parsed text. Shipped rights citations are
unaffected: they are hand-authored and lawyer-checked, not parsed.

## Run the API + demo

```bash
uvicorn backend.api:create_app --factory --host 127.0.0.1 --port 8000
```

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

## Notes and honest limitations

- Seed content is transcribed and cited from the 1999 Constitution but is marked
  "pending independent lawyer review"; it must be reviewed by a qualified Nigerian lawyer
  before any real launch.
- The offline retrieval uses a dependency-free TF-IDF embedder so the MVP runs without API
  keys. Swap in a hosted embedding/LLM provider via the `Embedder`/`Answerer` interfaces for
  higher answer quality, keeping the cite-or-refuse guardrails.
- The mobile (Flutter) client and Postgres/pgvector backing store described in `../MVP.md`
  are the next steps; this MVP ships the content engine, API, grounded Q&A, and a web demo.
