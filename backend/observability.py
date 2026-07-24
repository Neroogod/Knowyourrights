"""Structured logging, request IDs, and optional error tracking.

Logs are JSON lines so a log pipeline can parse them without regexes, and every
request carries an id that appears in its log line and in the `X-Request-ID`
response header, so a user's report can be traced to a single request.

Nothing here requires an external service to run. Sentry is initialised only when
`SENTRY_DSN` is set, so error tracking is a config switch, not a code change - and
the app runs identically without it.
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
import uuid
from collections.abc import Awaitable, Callable

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

REQUEST_ID_HEADER = "X-Request-ID"
_logger = logging.getLogger("kyr")


class JsonLogFormatter(logging.Formatter):
    """Render log records as single-line JSON."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, object] = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(record.created)),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        # Structured fields attached via logger.info(..., extra={"fields": {...}}).
        fields = getattr(record, "fields", None)
        if isinstance(fields, dict):
            payload.update(fields)
        if record.exc_info:
            payload["exc_info"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def configure_logging(level: str | None = None) -> None:
    """Send JSON logs to stdout. Idempotent, so repeated calls do not duplicate."""
    root = logging.getLogger()
    root.setLevel(level or os.getenv("KYR_LOG_LEVEL", "INFO"))
    for handler in list(root.handlers):
        if getattr(handler, "_kyr", False):
            return
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonLogFormatter())
    handler._kyr = True  # type: ignore[attr-defined]
    root.handlers = [handler]


def log_event(message: str, **fields: object) -> None:
    """Emit a structured log line with arbitrary fields."""
    _logger.info(message, extra={"fields": fields})


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Assign a request id, time the request, and log its outcome as JSON.

    An incoming `X-Request-ID` is honoured (so a client can correlate across
    services); otherwise one is minted. It is echoed on the response.
    """

    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        request_id = request.headers.get(REQUEST_ID_HEADER) or uuid.uuid4().hex
        request.state.request_id = request_id
        started = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            _logger.exception(
                "request failed",
                extra={
                    "fields": {
                        "request_id": request_id,
                        "method": request.method,
                        "path": request.url.path,
                    }
                },
            )
            raise
        elapsed_ms = int((time.perf_counter() - started) * 1000)
        response.headers[REQUEST_ID_HEADER] = request_id
        # The query string is dropped: an /ask URL can carry sensitive content.
        log_event(
            "request",
            request_id=request_id,
            method=request.method,
            path=request.url.path,
            status=response.status_code,
            latency_ms=elapsed_ms,
        )
        return response


def init_error_tracking() -> bool:
    """Initialise Sentry if configured. Returns True when active.

    Absent `SENTRY_DSN`, or the SDK, this is a silent no-op - the app is fully
    functional without it, which keeps error tracking a deployment concern rather
    than a hard dependency.
    """
    dsn = os.getenv("SENTRY_DSN")
    if not dsn:
        return False
    try:
        import sentry_sdk
    except ImportError:
        log_event("sentry unavailable", reason="sentry-sdk not installed")
        return False
    sentry_sdk.init(
        dsn=dsn,
        environment=os.getenv("KYR_ENVIRONMENT", "production"),
        traces_sample_rate=float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.0")),
        # Questions can be sensitive; never attach request bodies to error events.
        send_default_pii=False,
    )
    return True


if __name__ == "__main__":
    import io

    def test_json_formatter_includes_structured_fields() -> None:
        stream = io.StringIO()
        handler = logging.StreamHandler(stream)
        handler.setFormatter(JsonLogFormatter())
        logger = logging.getLogger("kyr.test")
        logger.handlers = [handler]
        logger.setLevel(logging.INFO)
        logger.info("hello", extra={"fields": {"request_id": "abc", "status": 200}})
        line = json.loads(stream.getvalue())
        assert line["message"] == "hello"
        assert line["request_id"] == "abc"
        assert line["status"] == 200
        assert line["level"] == "INFO"
        print("test_json_formatter_includes_structured_fields passed")

    def test_configure_logging_is_idempotent() -> None:
        configure_logging()
        first = list(logging.getLogger().handlers)
        configure_logging()
        assert logging.getLogger().handlers == first, "handlers should not duplicate"
        print("test_configure_logging_is_idempotent passed")

    def test_error_tracking_off_without_dsn() -> None:
        os.environ.pop("SENTRY_DSN", None)
        assert init_error_tracking() is False
        print("test_error_tracking_off_without_dsn passed")

    test_json_formatter_includes_structured_fields()
    test_configure_logging_is_idempotent()
    test_error_tracking_off_without_dsn()
    print("\nAll tests passed!")
