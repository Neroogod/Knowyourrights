# Deploying the KnowYourRights API

The backend is a self-contained FastAPI app. The verified content pack is built
into the image at build time, so there is no database to provision for the MVP.

Everything below assumes you are in the `knowyourrights/` folder.

---

## What is already prepared

| File | Purpose |
|------|---------|
| `Dockerfile` | Production image (Python 3.12, non-root, builds the content pack, binds `$PORT`). |
| `.dockerignore` | Keeps the Flutter app and caches out of the image. |
| `fly.toml` | Fly.io config (deploys from your machine, no GitHub needed). |
| `render.yaml` | Render.com Blueprint (free tier, no credit card, deploys from GitHub). |
| `Procfile` | Generic web/release commands for Heroku-style hosts. |

The server starts with:

```
uvicorn backend.api:create_app --factory --host 0.0.0.0 --port $PORT
```

Health check path: `/v1/health`.

---

## Option A — Render (free, no credit card)

1. Create a free account at https://render.com.
2. Push the `knowyourrights/` folder to a GitHub repo (a git repo is already
   initialised locally; add your remote and push):
   ```bash
   git remote add origin https://github.com/<you>/knowyourrights.git
   git push -u origin main
   ```
3. In Render: **New +** -> **Blueprint** -> pick the repo. Render reads
   `render.yaml` and deploys. First build takes a few minutes.
4. Your API will be live at `https://knowyourrights-api.onrender.com`.
   (Free instances sleep when idle and wake on the next request.)

**Live now:** `https://knowyourrights-api.onrender.com`  
Web demo: open that URL in a browser. Health: `/v1/health`.

## Option B — Fly.io (deploys straight from your Mac)

1. Install the CLI: `brew install flyctl`.
2. Log in / sign up: `fly auth login` (opens a browser). A payment card is
   required on file even for the free allowance.
3. From `knowyourrights/`:
   ```bash
   fly launch --copy-config --now
   ```
   Accept the app name/region. Fly builds the `Dockerfile` and deploys.
4. Your API will be live at `https://knowyourrights-api.fly.dev`.

---

## Point the app at the deployed API

The Flutter app reads its base URL from a compile-time variable
(`KYR_BASE_URL`), defaulting to `http://127.0.0.1:8000` for local dev. Build the
app against your deployed URL:

```bash
cd app
flutter build apk   --dart-define=KYR_BASE_URL=https://<your-host>
flutter build ios   --dart-define=KYR_BASE_URL=https://<your-host> --no-codesign
flutter build web   --dart-define=KYR_BASE_URL=https://<your-host>
```

Or run it live against the deployed API:

```bash
flutter run --dart-define=KYR_BASE_URL=https://<your-host>
```

---

## Verify a deployment

```bash
curl https://<your-host>/v1/health
curl -X POST https://<your-host>/v1/ask \
  -H 'Content-Type: application/json' \
  -d '{"question":"what are my rights when arrested?"}'
```

You should get `{"status":"ok",...}` and a grounded, cited answer.
