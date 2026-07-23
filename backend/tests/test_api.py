"""Integration tests for the HTTP API and the trust guardrails on /ask."""

from fastapi.testclient import TestClient


def test_health(client: TestClient) -> None:
    resp = client.get("/v1/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_list_topics(client: TestClient) -> None:
    resp = client.get("/v1/topics")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_filter_topics_by_category(client: TestClient) -> None:
    resp = client.get("/v1/topics", params={"category": "privacy-and-searches"})
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1 and body[0]["id"] == "privacy-and-phone-searches"


def test_get_topic_and_404(client: TestClient) -> None:
    assert client.get("/v1/topics/rights-when-arrested").status_code == 200
    assert client.get("/v1/topics/does-not-exist").status_code == 404


def test_scenarios(client: TestClient) -> None:
    resp = client.get("/v1/scenarios")
    assert resp.status_code == 200 and len(resp.json()) == 1


def test_directory(client: TestClient) -> None:
    resp = client.get("/v1/directory")
    assert resp.status_code == 200 and resp.json()[0]["entry_type"] == "legal_aid"


def test_search(client: TestClient) -> None:
    resp = client.get("/v1/search", params={"q": "search my phone"})
    assert resp.status_code == 200
    results = resp.json()
    assert results and results[0]["id"] == "privacy-and-phone-searches"


def test_ask_grounded_answer_has_citation(client: TestClient) -> None:
    resp = client.post("/v1/ask", json={"question": "can the police search my phone?"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["refused"] is False
    assert len(body["citations"]) >= 1
    assert body["citations"][0]["locator"] == "s.37"
    assert body["disclaimer"]


def test_ask_refuses_when_unknown(client: TestClient) -> None:
    resp = client.post("/v1/ask", json={"question": "what are today's lottery numbers?"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["refused"] is True
    assert body["citations"] == []
    assert body["disclaimer"]


def test_ask_never_answers_without_citation(client: TestClient) -> None:
    for question in [
        "I was arrested, what are my rights",
        "police stopped me and want my phone",
        "how long can I be held",
        "random unrelated question about cars",
    ]:
        body = client.post("/v1/ask", json={"question": question}).json()
        if not body["refused"]:
            assert len(body["citations"]) >= 1, f"uncited answer for: {question}"


def test_ask_validation_rejects_empty(client: TestClient) -> None:
    assert client.post("/v1/ask", json={"question": ""}).status_code == 422
