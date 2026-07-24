# Operations runbook

How this service is built, watched, backed up, and recovered. Paired with
`DEPLOY.md` (how to deploy) and `GOVERNANCE.md` (how content is trusted).

## 1. CI/CD

`.github/workflows/ci.yml` runs on every pull request and every push to `main`:

| Job | Gate |
|-----|------|
| **Backend** | `ruff check`, `ruff format --check`, `mypy` (advisory), the runnable pipeline self-tests, `pytest` with a **≥70 % coverage** floor, and a `pip-audit` dependency scan |
| **AI trust gate** | the RAG regression (`backend.rag.evaluate`) — accuracy, citation validity, and refusal correctness must clear their thresholds, and must not regress from the baseline |
| **Migration gate** | Alembic `upgrade head` → `downgrade base` → `upgrade head` on a scratch DB, and a check that there is exactly **one** migration head |
| **Flutter** | `flutter analyze` and `flutter test` |

Every command in the pipeline is one you can run locally; nothing in CI is
aspirational. `ai-trust-gate.yml` remains as a content-path-scoped fast check.

### Staging → production promotion

- Merges to `main` are the release candidate. Deploy them to **staging** first
  (Render/Fly service `knowyourrights-api-staging`, separate database and
  secrets), run the smoke checks in `DEPLOY.md`, then promote the same commit to
  production. Never build a separate production artifact — promote the tested one.
- **Migrations run as a gated deploy step, before app processes start:**
  `alembic upgrade head` against the production database, then release. The app
  never calls `create_all()` against PostgreSQL.

## 2. Observability

- **Structured logging:** JSON log lines to stdout (`backend/observability.py`),
  one per request, with a **request id**, method, path, status, and latency. The
  query string is never logged — an `/ask` URL can carry a sensitive question.
- **Request IDs:** every response carries `X-Request-ID`; an inbound one is
  honoured, so a user's report ties to a single request across services.
- **Error tracking:** Sentry initialises only when `SENTRY_DSN` is set
  (`send_default_pii=False`, so bodies are never attached). Absent the DSN it is a
  silent no-op — error tracking is a deployment switch, not a code change.
- **Dashboards (reviewer/administrator only, computed on demand):**
  - `GET /v1/admin/metrics/content-health` — verified/community/draft counts per
    content type, plus the stale backlog.
  - `GET /v1/admin/metrics/ai` — LLM volume, cost, latency (avg + p95), cache and
    refusal rates. Prompts are never stored, so this reports on cost without
    exposing what anyone asked.
  - `GET /v1/admin/metrics/trust-kpis` — refusal rate, verified-topic ratio, stale
    backlog, and error-report open/resolved counts with average resolution time.

These endpoints are the data source for whatever dashboard tool is chosen; the
numbers exist and are queryable today.

## 3. Backup and restore drill

PostgreSQL is the single source of truth (accounts + versioned content). Object
storage holds source PDFs and content packs.

**Backups**

- Enable automated daily PostgreSQL snapshots on the managed provider, retained
  30 days. Enable object-storage versioning.
- Content packs are reproducible from the repo (`build_pack.py`) and imported as
  immutable versions, so a content rollback is `content_cli` re-import of a prior
  version, not a database restore.

**Restore drill — run quarterly, on staging:**

```bash
# 1. Take a fresh dump of the source (or use the latest automated snapshot).
pg_dump "$SOURCE_DATABASE_URL" -Fc -f /tmp/kyr-backup.dump

# 2. Restore into an empty staging database.
createdb kyr_restore_test
pg_restore --clean --if-exists -d "$RESTORE_DATABASE_URL" /tmp/kyr-backup.dump

# 3. Verify the schema is current and content is intact.
DATABASE_URL="$RESTORE_DATABASE_URL" alembic current        # == head
DATABASE_URL="$RESTORE_DATABASE_URL" \
  python -c "from backend.content_db import content_repository_from_environment as r; \
             print('active pack:', r().load_active_pack().version)"

# 4. Point a throwaway app instance at the restored DB and hit /v1/health
#    plus one /v1/ask, confirming a grounded, cited answer.
```

Record the wall-clock restore time each drill; that number is the real RTO.

## 4. Disaster-recovery runbook

- **Targets:** RPO ≤ 24 h (daily snapshot), RTO ≤ 2 h (measured by the drill
  above; revise if a drill exceeds it).
- **Database loss:** provision a new managed PostgreSQL, restore the latest
  snapshot (section 3), run `alembic upgrade head`, re-import the active content
  pack if needed, then bring app processes up and run the `DEPLOY.md` smoke checks.
- **Secret compromise:** rotate `KYR_APP_SECRET` (invalidates tokens and
  re-keys encrypted profile/contact/location fields — plan for re-encryption),
  the Supabase keys, and the Resend/Twilio credentials in the managed secret
  store; redeploy.
- **Bad content release:** `content_cli` re-activates the previous immutable
  content version; no database restore required.
- **Region outage:** core rights and emergency scenarios keep working **offline**
  on every installed device (the content pack is bundled), so the highest-stakes
  path degrades gracefully even during a full backend outage.

## 5. Not yet in place — needs external services or accounts

These are wired-for or documented, but cannot be finished from the repo alone:

- **Automated iOS/Android distribution & staged rollout:** needs Apple Developer
  and Google Play accounts, signing certificates, and a Fastlane lane with those
  secrets. The Flutter CI job builds and tests; it does not sign or upload.
- **Crash-free-release gate:** needs a mobile crash reporter (Firebase
  Crashlytics or Sentry mobile) feeding a release-health metric to gate rollout.
- **APM, uptime/error dashboards, alerting:** the data (structured logs, request
  ids, the metrics endpoints, `SENTRY_DSN`) is ready; wiring it to a specific
  vendor (Grafana/Datadog/Better Stack) and setting alert thresholds is a
  deployment task with that vendor's account.
- **Content-health / trust-KPI dashboard UI:** the endpoints exist; rendering
  them as a live dashboard is follow-up.
