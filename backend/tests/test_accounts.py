"""Integration tests for verified onboarding and guarded custody alerts."""

import base64
import hashlib
import hmac
from datetime import UTC, datetime, timedelta
from urllib.parse import urlencode

from fastapi.testclient import TestClient
from sqlalchemy import select

from backend.accounts import (
    AccountService,
    AlertDeliveryRecord,
    AlertRecord,
    CheckInRecord,
    UserRoleRecord,
)
from backend.delivery import DeliveryError, DevelopmentGateway


class FlakyAlertGateway:
    def __init__(self) -> None:
        self.attempts = 0

    def send_email_verification(self, email: str, token: str) -> None:
        pass

    def send_password_reset(self, email: str, token: str) -> None:
        pass

    def send_contact_verification(
        self,
        phone: str,
        name: str,
        token: str,
        decline_token: str | None = None,
        withdrawal_token: str | None = None,
    ) -> None:
        pass

    def send_custody_alert(self, phone: str, message: str) -> str:
        self.attempts += 1
        if self.attempts == 1:
            raise DeliveryError("temporary failure")
        return "retry-success"


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
    assert (
        client.post(
            "/v1/auth/login",
            json={"email": "person@example.com", "password": "a-new-long-test-password"},
        ).status_code
        == 200
    )
    assert (
        client.post(
            "/v1/auth/reset-password",
            json={"token": token, "password": "another-long-test-password"},
        ).status_code
        == 400
    )


def test_account_export_and_deletion_require_authentication(client: TestClient) -> None:
    headers, _ = _register_and_login(client)
    client.put(
        "/v1/profile",
        headers=headers,
        json={"full_name": "Export Person", "phone": "+2348012345678"},
    )
    exported = client.get("/v1/account/export", headers=headers)
    assert exported.status_code == 200
    assert exported.json()["profile"]["email"] == "person@example.com"

    deleted = client.request(
        "DELETE",
        "/v1/account",
        headers=headers,
        json={"confirmation": "DELETE"},
    )
    assert deleted.status_code == 200
    assert deleted.json() == {"deleted": True}
    assert client.get("/v1/profile", headers=headers).status_code == 401


def test_roles_default_to_reader_and_only_admin_can_change_them(
    client: TestClient,
    account_service: AccountService,
) -> None:
    headers, _ = _register_and_login(client)
    with account_service.sessions.begin() as session:
        user_id = account_service.authenticate(headers["Authorization"].removeprefix("Bearer "))
        role = session.get(UserRoleRecord, user_id)
        assert role is not None
        role.role = "administrator"
    changed = client.put(
        f"/v1/admin/users/{user_id}/role",
        headers=headers,
        json={"role": "reviewer"},
    )
    assert changed.status_code == 200
    assert account_service.role(user_id) == "reviewer"


def test_login_is_rate_limited_per_ip_and_device(client: TestClient) -> None:
    headers = {"X-Device-ID": "abusive-device"}
    payload = {"email": "missing@example.com", "password": "wrong"}
    responses = [client.post("/v1/auth/login", headers=headers, json=payload) for _ in range(11)]
    assert responses[-1].status_code == 429


def test_contact_limit_decline_and_withdrawal(
    client: TestClient,
    account_service: AccountService,
) -> None:
    headers, _ = _register_and_login(client)
    gateway = account_service.gateway
    assert isinstance(gateway, DevelopmentGateway)

    client.post(
        "/v1/emergency-contacts",
        headers=headers,
        json={"name": "First Contact", "phone": "+2348011111111"},
    )
    decline = gateway.contact_decline_tokens["+2348011111111"]
    assert client.get(f"/contact-decline?token={decline}").status_code == 200
    assert client.get("/v1/emergency-contacts", headers=headers).json()[0]["status"] == "declined"

    for index in range(3):
        phone = f"+23480222222{index:02d}"
        created = client.post(
            "/v1/emergency-contacts",
            headers=headers,
            json={"name": f"Contact {index}", "phone": phone},
        )
        assert created.status_code == 200
    fourth = client.post(
        "/v1/emergency-contacts",
        headers=headers,
        json={"name": "Too Many", "phone": "+2348033333333"},
    )
    assert fourth.status_code == 400

    withdrawal = gateway.contact_withdrawal_tokens["+2348022222200"]
    assert client.get(f"/contact-withdraw?token={withdrawal}").status_code == 200


def test_test_alert_tracking_station_and_safe_walk(
    client: TestClient,
    account_service: AccountService,
) -> None:
    headers, _ = _register_and_login(client)
    client.put(
        "/v1/profile",
        headers=headers,
        json={"full_name": "Safety Person", "phone": "+2348012345678"},
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
        json={
            "contact_id": contact["id"],
            "idempotency_key": "test-tracking-alert",
            "station_name": "Area F Station",
            "is_test": True,
        },
    )
    body = alert.json()
    assert body["is_test"] is True
    assert body["station_name"] == "Area F Station"
    token = body["tracking_url"].rsplit("/", 1)[-1]
    public = client.get(f"/v1/public/custody-alerts/{token}")
    assert public.status_code == 200
    assert public.json()["sender_name"] == "Safety Person"

    armed = client.post("/v1/check-ins", headers=headers, json={"minutes": 5})
    check_in_id = armed.json()["id"]
    with account_service.sessions.begin() as session:
        record = session.get(CheckInRecord, check_in_id)
        assert record is not None
        record.due_at = datetime.now(UTC) - timedelta(seconds=1)
    assert account_service.process_due_check_ins() == 1
    history = client.get("/v1/custody-alerts", headers=headers).json()
    assert any(item["id"] != body["id"] for item in history)


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
    assert first.json()["deliveries"] == [
        {
            "channel": "gateway_sms",
            "status": "sent",
            "attempts": 1,
            "updated_at": first.json()["deliveries"][0]["updated_at"],
        }
    ]
    assert second.status_code == 200 and second.json()["duplicate"] is True

    cancelled = client.post(
        f"/v1/custody-alerts/{first.json()['id']}/cancel",
        headers=headers,
    )
    assert cancelled.status_code == 200
    assert cancelled.json()["status"] == "cancelled"
    assert cancelled.json()["deliveries"][-1]["channel"] == "gateway_sms_follow_up"
    assert cancelled.json()["deliveries"][-1]["status"] == "sent"


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


def test_delivery_callback_requires_secret_and_records_delivery(
    client: TestClient,
    monkeypatch,
) -> None:
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
        json={"contact_id": contact["id"], "idempotency_key": "delivery-callback-123"},
    )
    assert alert.status_code == 200

    payload = {"provider_message_id": "dev-1", "status": "delivered"}
    assert client.post("/v1/custody-alerts/delivery-callback", json=payload).status_code == 401
    monkeypatch.setenv("KYR_DELIVERY_WEBHOOK_SECRET", "callback-test-secret")
    delivered = client.post(
        "/v1/custody-alerts/delivery-callback",
        json=payload,
        headers={"X-KYR-Webhook-Secret": "callback-test-secret"},
    )
    assert delivered.status_code == 200
    assert delivered.json()["status"] == "delivered"
    assert delivered.json()["deliveries"][0]["status"] == "delivered"

    resolved = client.post(
        f"/v1/custody-alerts/{alert.json()['id']}/resolve",
        headers=headers,
    )
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"


def test_twilio_delivery_callback_validates_signature(
    client: TestClient,
    monkeypatch,
) -> None:
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
    client.post(
        "/v1/custody-alerts",
        headers=headers,
        json={"contact_id": contact["id"], "idempotency_key": "twilio-callback-123"},
    )

    public_url = "https://rights.example"
    auth_token = "twilio-test-secret"
    callback_url = f"{public_url}/v1/custody-alerts/twilio-callback"
    params = {"MessageSid": "dev-1", "MessageStatus": "delivered"}
    signed = callback_url + "".join(f"{key}{value}" for key, value in sorted(params.items()))
    signature = base64.b64encode(
        hmac.new(auth_token.encode(), signed.encode(), hashlib.sha1).digest()
    ).decode()
    monkeypatch.setenv("KYR_PUBLIC_BASE_URL", public_url)
    monkeypatch.setenv("TWILIO_AUTH_TOKEN", auth_token)

    delivered = client.post(
        "/v1/custody-alerts/twilio-callback",
        content=urlencode(params),
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "X-Twilio-Signature": signature,
        },
    )
    assert delivered.status_code == 200
    assert delivered.json()["status"] == "delivered"


def test_location_retention_purge_removes_old_coordinates(
    client: TestClient,
    account_service: AccountService,
) -> None:
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
        json={
            "contact_id": contact["id"],
            "idempotency_key": "retention-purge-123",
            "latitude": 6.5244,
            "longitude": 3.3792,
        },
    ).json()
    with account_service.sessions.begin() as session:
        record = session.get(AlertRecord, alert["id"])
        assert record is not None
        record.triggered_at = datetime.now(UTC) - timedelta(hours=25)

    assert account_service.purge_expired_locations() == 1
    refreshed = client.get(f"/v1/custody-alerts/{alert['id']}", headers=headers)
    assert refreshed.json()["location_shared"] is False


def test_failed_alert_is_retried_with_attempt_tracking(
    client: TestClient,
    account_service: AccountService,
) -> None:
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
    gateway = FlakyAlertGateway()
    account_service.gateway = gateway
    alert = client.post(
        "/v1/custody-alerts",
        headers=headers,
        json={"contact_id": contact["id"], "idempotency_key": "retry-alert-123"},
    ).json()
    assert alert["status"] == "failed"
    assert alert["deliveries"][0]["attempts"] == 1

    with account_service.sessions.begin() as session:
        delivery = session.scalar(
            select(AlertDeliveryRecord).where(AlertDeliveryRecord.alert_id == alert["id"])
        )
        assert delivery is not None
        delivery.next_retry_at = datetime.now(UTC) - timedelta(seconds=1)

    assert account_service.retry_due_alerts() == 1
    refreshed = client.get(f"/v1/custody-alerts/{alert['id']}", headers=headers).json()
    assert refreshed["status"] == "sent"
    assert refreshed["deliveries"][0]["attempts"] == 2
