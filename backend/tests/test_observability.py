"""Observability: request IDs, structured logs, and the admin dashboards.

The dashboards are computed from data already held and never expose a user's
question; they are reviewer-only. These tests pin the access rule and the shape.
"""

from fastapi.testclient import TestClient


def _reviewer(client: TestClient, account_service, email: str) -> dict:
    created = client.post("/v1/auth/register", json={"email": email, "password": "Str0ngPassw0rd!23"})
    client.post("/v1/auth/verify-email", json={"token": created.json()["development_verification_token"]})
    token = client.post("/v1/auth/login", json={"email": email, "password": "Str0ngPassw0rd!23"}).json()[
        "access_token"
    ]
    user_id = account_service.authenticate(token)
    with account_service.sessions.begin() as session:
        from backend.accounts import UserRoleRecord

        session.get(UserRoleRecord, user_id).role = "reviewer"
    return {"Authorization": f"Bearer {token}"}


def test_every_response_carries_a_request_id(client: TestClient):
    response = client.get("/v1/health")
    assert response.headers.get("X-Request-ID")


def test_an_incoming_request_id_is_honoured(client: TestClient):
    response = client.get("/v1/health", headers={"X-Request-ID": "trace-123"})
    assert response.headers["X-Request-ID"] == "trace-123"


def test_content_health_requires_a_reviewer(client: TestClient):
    assert client.get("/v1/admin/metrics/content-health").status_code == 401


def test_content_health_reports_status_breakdown(client: TestClient, account_service):
    headers = _reviewer(client, account_service, "obs1@example.com")
    data = client.get("/v1/admin/metrics/content-health", headers=headers).json()
    assert data["content"]["topics"]["total"] >= 1
    assert "verified" in data["content"]["topics"]["by_status"]
    assert "stale_count" in data


def test_ai_metrics_never_expose_prompts(client: TestClient, account_service):
    headers = _reviewer(client, account_service, "obs2@example.com")
    # Generate one answer so there is something to aggregate.
    client.post("/v1/ask", json={"question": "can police search my phone?"})
    data = client.get("/v1/admin/metrics/ai", headers=headers).json()
    assert data["questions"] >= 1
    assert "estimated_cost_usd" in data
    assert "latency_ms_p95" in data
    # The summary is aggregate only; no field should carry question text.
    assert "question" not in data and "prompt" not in data


def test_trust_kpis_shape(client: TestClient, account_service):
    headers = _reviewer(client, account_service, "obs3@example.com")
    data = client.get("/v1/admin/metrics/trust-kpis", headers=headers).json()
    assert "verified_topics" in data
    assert "stale_backlog" in data
    assert "error_reports" in data and "open" in data["error_reports"]


def test_ai_metrics_empty_window_is_safe(client: TestClient, account_service):
    headers = _reviewer(client, account_service, "obs4@example.com")
    # A 1-day window with no traffic must not divide by zero.
    data = client.get("/v1/admin/metrics/ai", headers=headers, params={"days": 1}).json()
    assert data["questions"] >= 0
