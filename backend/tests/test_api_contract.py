"""API-contract additions: categories, content filters, unified Ask, incognito,
and the structured error envelope.

The envelope change is additive by design: every error still carries the plain
`detail` field older clients read, plus the `error: {code, message, details}`
object the contract specifies. These tests pin both so a future refactor cannot
quietly break either side.
"""

from fastapi.testclient import TestClient

# ------------------------------------------------------------- categories


def test_categories_list_with_counts(client: TestClient):
    response = client.get("/v1/categories")
    assert response.status_code == 200
    data = response.json()
    ids = {c["id"] for c in data}
    assert "arrest-and-police" in ids
    for category in data:
        assert category["topic_count"] >= 1


def test_categories_carry_an_etag(client: TestClient):
    response = client.get("/v1/categories")
    assert response.headers.get("ETag")
    # Stable across identical requests, since content has not changed.
    assert client.get("/v1/categories").headers["ETag"] == response.headers["ETag"]


# --------------------------------------------------------- content filters


def test_topics_filter_by_status(client: TestClient):
    verified = client.get("/v1/topics", params={"status": "verified"}).json()
    assert verified
    assert all(t["status"] == "verified" for t in verified)
    assert client.get("/v1/topics", params={"status": "draft"}).json() == []


def test_topics_filter_by_jurisdiction(client: TestClient):
    hit = client.get("/v1/topics", params={"jurisdiction": "NG-Federal"}).json()
    assert hit
    assert client.get("/v1/topics", params={"jurisdiction": "NG-Lagos"}).json() == []


def test_topic_filters_combine_with_category(client: TestClient):
    result = client.get(
        "/v1/topics",
        params={"category": "arrest-and-police", "status": "verified"},
    ).json()
    assert all(t["category"] == "arrest-and-police" for t in result)


# ------------------------------------------------------------- unified Ask


def test_ask_routes_by_audience(client: TestClient):
    for audience in ("individual", "business", "student"):
        response = client.post(
            "/v1/ask", params={"audience": audience}, json={"question": "what are my rights?"}
        )
        assert response.status_code == 200
        assert "refused" in response.json()


def test_ask_rejects_an_unknown_audience(client: TestClient):
    response = client.post("/v1/ask", params={"audience": "alien"}, json={"question": "x"})
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "bad_request"


def test_business_audience_answers_from_the_company_corpus(client: TestClient):
    # A rights question through the business audience should not surface rights
    # content; the corpora are kept apart by the audience selector.
    rights = client.post(
        "/v1/ask", params={"audience": "individual"}, json={"question": "can police search my phone?"}
    ).json()
    business = client.post(
        "/v1/ask", params={"audience": "business"}, json={"question": "can police search my phone?"}
    ).json()
    # The individual corpus has this topic; the company corpus does not.
    assert rights["refused"] is False
    assert business["refused"] is True


# -------------------------------------------------------------- incognito


def test_incognito_leaves_no_event(client: TestClient):
    normal = client.post("/v1/ask", json={"question": "can police search my phone?"})
    assert normal.headers["X-AI-Event-ID"] != "incognito"

    private = client.post(
        "/v1/ask",
        headers={"X-KYR-Incognito": "1"},
        json={"question": "can police search my phone?"},
    )
    assert private.status_code == 200
    # The sentinel event id means nothing was cached or recorded.
    assert private.headers["X-AI-Event-ID"] == "incognito"


def test_incognito_still_answers(client: TestClient):
    response = client.post(
        "/v1/ask",
        headers={"X-KYR-Incognito": "true"},
        json={"question": "can police search my phone?"},
    )
    assert response.status_code == 200
    assert response.json()["refused"] is False


# ---------------------------------------------------------- error envelope


def test_not_found_uses_the_structured_envelope(client: TestClient):
    response = client.get("/v1/topics/does-not-exist")
    assert response.status_code == 404
    body = response.json()
    # Both shapes present: old clients read detail, the contract reads error.
    assert body["detail"]
    assert body["error"]["code"] == "not_found"
    assert body["error"]["message"] == body["detail"]


def test_validation_error_uses_the_envelope(client: TestClient):
    # Missing the required question field.
    response = client.post("/v1/ask", json={})
    assert response.status_code == 422
    body = response.json()
    assert body["error"]["code"] == "validation_error"
    assert isinstance(body["error"]["details"], list)


def test_unauthorized_uses_the_envelope(client: TestClient):
    response = client.get("/v1/profile")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


# --------------------------------------------------- reading history (sync)


def _auth(client: TestClient, email: str) -> dict:
    created = client.post("/v1/auth/register", json={"email": email, "password": "Str0ngPassw0rd!23"})
    client.post("/v1/auth/verify-email", json={"token": created.json()["development_verification_token"]})
    token = client.post("/v1/auth/login", json={"email": email, "password": "Str0ngPassw0rd!23"}).json()[
        "access_token"
    ]
    return {"Authorization": f"Bearer {token}"}


def test_reading_history_and_saved_topics_sync(client: TestClient):
    headers = _auth(client, "history@example.com")
    now = "2026-07-24T10:00:00+00:00"
    client.post(
        "/v1/sync",
        headers=headers,
        json={
            "items": [
                {
                    "kind": "history",
                    "item_id": "rights-when-arrested",
                    "payload": {"type": "topic"},
                    "deleted": False,
                    "updated_at": now,
                },
                {
                    "kind": "saved",
                    "item_id": "privacy-and-phone-searches",
                    "payload": {"type": "topic"},
                    "deleted": False,
                    "updated_at": now,
                },
                {
                    "kind": "preference",
                    "item_id": "notifications",
                    "payload": {"legal_changes": True},
                    "deleted": False,
                    "updated_at": now,
                },
            ]
        },
    )
    pulled = client.get("/v1/sync", headers=headers).json()["items"]
    kinds = {item["kind"] for item in pulled}
    assert {"history", "saved", "preference"}.issubset(kinds)
    prefs = next(i for i in pulled if i["kind"] == "preference")
    assert prefs["payload"]["legal_changes"] is True
