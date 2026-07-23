"""Production delivery adapter contract tests without network access."""

import httpx
import pytest

from backend.delivery import DeliveryError, ProductionGateway


def _gateway(handler) -> ProductionGateway:
    return ProductionGateway(
        public_base_url="https://rights.example",
        resend_api_key="re_test",
        email_from="Know Your Rights <safety@rights.example>",
        twilio_account_sid="ACtest",
        twilio_auth_token="secret",
        twilio_from="+15551234567",
        client=httpx.Client(transport=httpx.MockTransport(handler)),
    )


def test_production_gateway_builds_email_and_sms_requests() -> None:
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if request.url.host == "api.resend.com":
            return httpx.Response(200, json={"id": "email-1"})
        return httpx.Response(201, json={"sid": "SM123", "status": "queued"})

    gateway = _gateway(handler)
    gateway.send_email_verification("person@example.com", "verify-token")
    gateway.send_password_reset("person@example.com", "reset-token")
    gateway.send_contact_verification("+2348012345678", "Trusted Person", "contact-token")
    message_id = gateway.send_custody_alert("+2348012345678", "Custody alert")

    assert message_id == "SM123"
    assert requests[0].url.path == "/emails"
    assert b"verify-email" in requests[0].content
    assert b"reset_token" in requests[1].content
    assert b"contact-verification" in requests[2].content
    assert b"Custody+alert" in requests[3].content


def test_production_gateway_reports_provider_failure() -> None:
    gateway = _gateway(lambda _request: httpx.Response(503, text="unavailable"))
    with pytest.raises(DeliveryError):
        gateway.send_custody_alert("+2348012345678", "Custody alert")
