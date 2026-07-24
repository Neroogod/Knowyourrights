"""Monetization: plans, tiered AI quota, and the payment flow.

The load-bearing test here is the guardrail: a free user, and an anonymous user,
must keep full access to rights, scenarios, and the directory. Money buys a larger
AI question quota and nothing else. If a future change paywalls a right, these
tests fail.
"""

from fastapi.testclient import TestClient

from backend import billing


def _auth(client: TestClient, email: str) -> dict:
    created = client.post("/v1/auth/register", json={"email": email, "password": "Str0ngPassw0rd!23"})
    client.post("/v1/auth/verify-email", json={"token": created.json()["development_verification_token"]})
    token = client.post("/v1/auth/login", json={"email": email, "password": "Str0ngPassw0rd!23"}).json()[
        "access_token"
    ]
    return {"Authorization": f"Bearer {token}"}


# ------------------------------------------------------------- the guardrail


def test_rights_content_is_free_for_anonymous_users(client: TestClient):
    # No account, no plan — full access to the things that matter most.
    assert client.get("/v1/topics").status_code == 200
    assert client.get("/v1/scenarios").status_code == 200
    assert client.get("/v1/directory").status_code == 200
    assert client.get("/v1/categories").status_code == 200


def test_rights_content_is_free_for_the_free_plan(client: TestClient):
    headers = _auth(client, "free@example.com")
    assert client.get("/v1/billing/subscription", headers=headers).json()["plan"] == "free"
    # Still every right, in full.
    assert len(client.get("/v1/topics", headers=headers).json()) >= 1
    assert client.get("/v1/scenarios", headers=headers).status_code == 200


def test_a_plan_can_only_change_the_ai_quota():
    # Structural guarantee: the plan table exposes nothing but the quota (+ price/label).
    for limits in billing.PLAN_LIMITS.values():
        assert set(limits) == {"ai_daily_quota", "price_kobo", "label"}


# ---------------------------------------------------------------- plans


def test_plans_endpoint_lists_the_catalogue(client: TestClient):
    plans = client.get("/v1/billing/plans").json()["plans"]
    ids = {p["id"] for p in plans}
    assert {"free", "premium", "student", "team"}.issubset(ids)
    free = next(p for p in plans if p["id"] == "free")
    assert free["price_naira"] == 0


def test_free_is_the_floor():
    assert billing.ai_daily_quota("free") <= billing.ai_daily_quota("premium")
    assert billing.ai_daily_quota("lapsed-or-unknown") == billing.ai_daily_quota("free")


# ------------------------------------------------------------- tiered quota


def test_default_quota_is_the_free_plan(client: TestClient, account_service):
    headers = _auth(client, "quota@example.com")
    body = client.get("/v1/billing/subscription", headers=headers).json()
    assert body["ai_daily_quota"] == billing.ai_daily_quota("free")


def test_activation_raises_the_quota(client: TestClient, account_service):
    headers = _auth(client, "upgrade@example.com")
    user_id = account_service.authenticate(headers["Authorization"].split()[1])
    account_service.activate_subscription(
        subject_id=user_id, plan="premium", provider="development", reference="ref-x"
    )
    body = client.get("/v1/billing/subscription", headers=headers).json()
    assert body["plan"] == "premium"
    assert body["ai_daily_quota"] == billing.ai_daily_quota("premium")


def test_lapsed_subscription_falls_back_to_free(account_service):
    from datetime import timedelta

    from backend.accounts import SubscriptionRecord

    user = "lapsed-user"
    with account_service.sessions.begin() as session:
        now = account_service._now()
        session.add(
            SubscriptionRecord(
                id="s1",
                subject_type="user",
                subject_id=user,
                plan="premium",
                status="active",
                provider="development",
                provider_reference="old-ref",
                current_period_end=now - timedelta(days=1),  # expired yesterday
                created_at=now,
                updated_at=now,
            )
        )
    assert account_service.active_plan(user) == "free"
    assert account_service.ai_quota_for(user) == billing.ai_daily_quota("free")


# --------------------------------------------------------------- checkout


def test_checkout_requires_an_account(client: TestClient):
    assert client.post("/v1/billing/checkout", json={"plan": "premium"}).status_code == 401


def test_checkout_returns_an_authorization_url(client: TestClient):
    headers = _auth(client, "checkout@example.com")
    body = client.post("/v1/billing/checkout", headers=headers, json={"plan": "premium"}).json()
    assert body["authorization_url"]
    assert body["reference"].startswith("kyr_")


def test_checkout_rejects_the_free_plan(client: TestClient):
    headers = _auth(client, "nofree@example.com")
    # You cannot "buy" free; the schema only accepts paid plans.
    assert client.post("/v1/billing/checkout", headers=headers, json={"plan": "free"}).status_code == 422


# ---------------------------------------------------------------- webhook


def test_webhook_activates_the_bound_subscription(client: TestClient, account_service):
    headers = _auth(client, "webhook@example.com")
    checkout = client.post("/v1/billing/checkout", headers=headers, json={"plan": "premium"}).json()
    reference = checkout["reference"]

    # The development gateway treats any signature as valid and any status "success".
    response = client.post(
        "/v1/billing/webhook/development",
        json={"reference": reference, "status": "success", "plan": "premium"},
    )
    assert response.status_code == 204
    assert client.get("/v1/billing/subscription", headers=headers).json()["plan"] == "premium"


def test_webhook_for_an_unknown_reference_grants_nothing(client: TestClient, account_service):
    # A forged webhook carrying a reference we never issued must not create a plan.
    before = account_service.active_plan("nobody")
    response = client.post(
        "/v1/billing/webhook/development",
        json={"reference": "never-issued", "status": "success", "plan": "team"},
    )
    assert response.status_code == 204
    assert not account_service.fulfil_checkout("never-issued", "team", "development")
    assert account_service.active_plan("nobody") == before


def test_webhook_activation_is_idempotent(client: TestClient, account_service):
    headers = _auth(client, "idem@example.com")
    reference = client.post("/v1/billing/checkout", headers=headers, json={"plan": "student"}).json()[
        "reference"
    ]
    payload = {"reference": reference, "status": "success", "plan": "student"}
    client.post("/v1/billing/webhook/development", json=payload)
    client.post("/v1/billing/webhook/development", json=payload)  # delivered twice
    # Exactly one active subscription, still student.
    from backend.accounts import SubscriptionRecord

    with account_service.sessions() as session:
        rows = session.query(SubscriptionRecord).filter_by(provider_reference=reference).all()
    assert len(rows) == 1 and rows[0].status == "active"
