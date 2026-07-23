# Production image for the KnowYourRights API.
# Python 3.12 (stable, well-supported wheels). The verified content pack is built
# into the image so the container is self-contained and needs no source PDFs.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Build and validate the content pack at image-build time. This enforces the
# "verified content must be cited" rule; the build fails if any record is invalid.
RUN python content_pipeline/build_pack.py --run

# Drop root for runtime.
RUN useradd --create-home --uid 10001 appuser && chown -R appuser /app
USER appuser

EXPOSE 8000

# Shell form so ${PORT} (injected by most hosts) expands; defaults to 8000.
CMD ["sh", "-c", "uvicorn backend.api:create_app --factory --host 0.0.0.0 --port ${PORT:-8000}"]
