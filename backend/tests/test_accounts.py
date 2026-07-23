"""Integration tests for verified onboarding and guarded custody alerts."""

from fastapi.testclient import TestClient


def _register_and_login(client: TestClient) -> tuple[dict[str, str], str]:
    registration = client.post(
        "/v1/auth/register",
        json={"email": "person@example.com", "password": "a-long-test-password"},
    )
    assert registration.status_code == 200
    verification = registration.json()["development_verification_token"]
    assert verification
    assert client.post("/v1/auth/verify-email", json={"token": verification}).status_code == 200
    second_use = client.post("/v1/auth/verify-email", json={"token": verification})
    assert second_use.status_code == 400
    login = client.post(
        "/v1/auth/login",
        json={"email": "person@example.com", "password": "a-long-test-password"},
    )
    assert login.status_code == 200
    token = login.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}, token


def test_registration_notifies_existing_email(client: TestClient) -> None:
    payload = {"email": "same@example.com", "password": "a-long-test-password"}
    first = client.post("/v1/auth/register", json=payload)
    second = client.post("/v1/auth/register", json=payload)
    assert first.json()["message"] == second.json()["message"]
    assert first.json()["account_exists"] is False
    assert second.json()["account_exists"] is True
    assert second.json()["development_verification_token"] is None


def test_unverified_user_can_request_a_fresh_verification(client: TestClient) -> None:
    payload = {"email": "resend@example.com", "password": "a-long-test-password"}
    client.post("/v1/auth/register", json=payload)
    resent = client.post("/v1/auth/resend-verification", json={"email": payload["email"]})
    token = resent.json()["development_verification_token"]
    assert resent.status_code == 200
    assert token
    assert client.post("/v1/auth/verify-email", json={"token": token}).status_code == 200


def test_verified_user_can_reset_password_once(client: TestClient) -> None:
    _register_and_login(client)
    reset = client.post("/v1/auth/forgot-password", json={"email": "person@example.com"})
    token = reset.json()["development_reset_token"]
    assert reset.status_code == 200
    assert token
    changed = client.post(
        "/v1/auth/reset-password",
        json={"token": token, "password": "a-new-long-test-password"},
    )
    assert changed.status_code == 200
    assert client.post(
        "/v1/auth/login",
        json={"email": "person@example.com", "password": "a-new-long-test-password"},
    ).status_code == 200
    assert client.post(
        "/v1/auth/reset-password",
        json={"token": token, "password": "another-long-test-password"},
    ).status_code == 400


def test_verified_onboarding_contact_consent_and_idempotent_alert(client: TestClient) -> None:
    headers, _ = _register_and_login(client)
    assert client.get("/v1/profile").status_code == 401

    profile = client.put(
        "/v1/profile",
        headers=headers,
        json={"full_name": "Test Person", "phone": "+2348012345678"},
    )
    assert profile.status_code == 200 and profile.json()["onboarding_complete"] is True

    contact = client.post(
        "/v1/emergency-contacts",
        headers=headers,
        json={"name": "Trusted Person", "phone": "+2348098765432"},
    )
    assert contact.status_code == 200
    body = contact.json()

    rejected = client.post(
        "/v1/custody-alerts",
        headers=headers,
        json={"contact_id": body["id"], "idempotency_key": "alert-key-123"},
    )
    assert rejected.status_code == 400

    verification = body["development_verification_token"]
    assert (
        client.post(
            "/v1/emergency-contacts/verify",
            json={"token": verification},
        ).status_code
        == 200
    )

    alert_payload = {
        "contact_id": body["id"],
        "idempotency_key": "alert-key-123",
        "latitude": 6.5244,
        "longitude": 3.3792,
        "accuracy": 20,
    }
    first = client.post("/v1/custody-alerts", headers=headers, json=alert_payload)
    second = client.post("/v1/custody-alerts", headers=headers, json=alert_payload)
    assert first.status_code == 200 and first.json()["status"] == "sent"
    assert first.json()["location_shared"] is True
    assert second.status_code == 200 and second.json()["duplicate"] is True


def test_alert_can_send_without_location(client: TestClient) -> None:
    headers, _ = _register_and_login(client)
    client.put(
        "/v1/profile",
        headers=headers,
        json={"full_name": "Test Person", "phone": "+2348012345678"},
    )
    contact = client.post(
        "/v1/emergency-contacts",
        headers=headers,
        json={"name": "Trusted Person", "phone": "+2348098765432"},
    ).json()
    client.post(
        "/v1/emergency-contacts/verify",
        json={"token": contact["development_verification_token"]},
    )
    alert = client.post(
        "/v1/custody-alerts",
        headers=headers,
        json={"contact_id": contact["id"], "idempotency_key": "no-location-123"},
    )
    assert alert.status_code == 200
    assert alert.json()["location_shared"] is False
