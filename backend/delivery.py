"""Development and production email/SMS delivery adapters."""

import os
from typing import Protocol
from urllib.parse import urlencode

import httpx


class DeliveryError(RuntimeError):
    """A delivery provider did not accept a message."""


class DeliveryGateway(Protocol):
    def send_email_verification(self, email: str, token: str) -> None: ...

    def send_password_reset(self, email: str, token: str) -> None: ...

    def send_contact_verification(
        self,
        phone: str,
        name: str,
        token: str,
        decline_token: str | None = None,
        withdrawal_token: str | None = None,
    ) -> None: ...

    def send_custody_alert(self, phone: str, message: str) -> str: ...

    def send_custody_alert_channel(
        self, channel: str, destination: str, message: str
    ) -> str: ...


class DevelopmentGateway:
    """Non-sending adapter used for local development and tests."""

    def __init__(self) -> None:
        self.email_tokens: dict[str, str] = {}
        self.reset_tokens: dict[str, str] = {}
        self.contact_tokens: dict[str, str] = {}
        self.contact_decline_tokens: dict[str, str] = {}
        self.contact_withdrawal_tokens: dict[str, str] = {}
        self.alerts: list[tuple[str, str]] = []

    def send_email_verification(self, email: str, token: str) -> None:
        self.email_tokens[email] = token

    def send_password_reset(self, email: str, token: str) -> None:
        self.reset_tokens[email] = token

    def send_contact_verification(
        self,
        phone: str,
        name: str,
        token: str,
        decline_token: str | None = None,
        withdrawal_token: str | None = None,
    ) -> None:
        self.contact_tokens[phone] = token
        if decline_token:
            self.contact_decline_tokens[phone] = decline_token
        if withdrawal_token:
            self.contact_withdrawal_tokens[phone] = withdrawal_token

    def send_custody_alert(self, phone: str, message: str) -> str:
        self.alerts.append((phone, message))
        return f"dev-{len(self.alerts)}"

    def send_custody_alert_channel(
        self, channel: str, destination: str, message: str
    ) -> str:
        self.alerts.append((f"{channel}:{destination}", message))
        return f"dev-{channel}-{len(self.alerts)}"


class ProductionGateway:
    """Resend email and Twilio SMS adapter."""

    def __init__(
        self,
        *,
        public_base_url: str,
        resend_api_key: str,
        email_from: str,
        twilio_account_sid: str,
        twilio_auth_token: str,
        twilio_from: str,
        client: httpx.Client | None = None,
    ) -> None:
        self.public_base_url = public_base_url.rstrip("/")
        self.resend_api_key = resend_api_key
        self.email_from = email_from
        self.twilio_account_sid = twilio_account_sid
        self.twilio_auth_token = twilio_auth_token
        self.twilio_from = twilio_from
        self.client = client or httpx.Client(timeout=10)

    @classmethod
    def from_environment(cls) -> "ProductionGateway":
        names = (
            "KYR_PUBLIC_BASE_URL",
            "RESEND_API_KEY",
            "KYR_EMAIL_FROM",
            "TWILIO_ACCOUNT_SID",
            "TWILIO_AUTH_TOKEN",
            "TWILIO_FROM",
        )
        values = {name: os.getenv(name) for name in names}
        missing = [name for name, value in values.items() if not value]
        if missing:
            raise RuntimeError(f"production delivery configuration missing: {', '.join(missing)}")
        return cls(
            public_base_url=str(values["KYR_PUBLIC_BASE_URL"]),
            resend_api_key=str(values["RESEND_API_KEY"]),
            email_from=str(values["KYR_EMAIL_FROM"]),
            twilio_account_sid=str(values["TWILIO_ACCOUNT_SID"]),
            twilio_auth_token=str(values["TWILIO_AUTH_TOKEN"]),
            twilio_from=str(values["TWILIO_FROM"]),
        )

    def send_email_verification(self, email: str, token: str) -> None:
        link = f"{self.public_base_url}/verify-email?{urlencode({'token': token})}"
        self._send_email(email, "Verify your Know Your Rights email", f"Verify your email: {link}")

    def send_password_reset(self, email: str, token: str) -> None:
        query = urlencode({"reset_token": token, "email": email})
        link = f"{self.public_base_url}/?{query}"
        self._send_email(email, "Reset your Know Your Rights password", f"Reset your password: {link}")

    def send_contact_verification(
        self,
        phone: str,
        name: str,
        token: str,
        decline_token: str | None = None,
        withdrawal_token: str | None = None,
    ) -> None:
        confirm = f"{self.public_base_url}/contact-verification?{urlencode({'token': token})}"
        decline = (
            f"{self.public_base_url}/contact-decline?{urlencode({'token': decline_token})}"
            if decline_token
            else ""
        )
        withdraw = (
            f"{self.public_base_url}/contact-withdraw?{urlencode({'token': withdrawal_token})}"
            if withdrawal_token
            else ""
        )
        self._send_sms(
            phone,
            f"{name}, you were added as a Know Your Rights emergency contact. "
            f"Confirm consent: {confirm}. Decline: {decline}. "
            f"You can withdraw later: {withdraw}",
        )

    def send_custody_alert(self, phone: str, message: str) -> str:
        return self._send_sms(
            phone,
            message,
            status_callback=f"{self.public_base_url}/v1/custody-alerts/twilio-callback",
        )

    def send_custody_alert_channel(
        self, channel: str, destination: str, message: str
    ) -> str:
        if channel == "email":
            return self._send_email(
                destination,
                "Custody Alert from Know Your Rights",
                message,
            )
        if channel == "whatsapp":
            whatsapp_from = os.getenv("TWILIO_WHATSAPP_FROM")
            if not whatsapp_from:
                raise DeliveryError("WhatsApp delivery is not configured")
            return self._send_sms(
                f"whatsapp:{destination.removeprefix('whatsapp:')}",
                message,
                sender=f"whatsapp:{whatsapp_from.removeprefix('whatsapp:')}",
            )
        if channel == "push":
            webhook = os.getenv("KYR_PUSH_WEBHOOK_URL")
            secret = os.getenv("KYR_PUSH_WEBHOOK_SECRET")
            if not webhook or not secret:
                raise DeliveryError("push delivery is not configured")
            try:
                response = self.client.post(
                    webhook,
                    headers={"Authorization": f"Bearer {secret}"},
                    json={"token": destination, "title": "Custody Alert", "body": message},
                )
                response.raise_for_status()
                return str(response.json().get("id") or f"push-{destination[:12]}")
            except httpx.HTTPError as error:
                raise DeliveryError("push provider did not accept the message") from error
        raise DeliveryError("unsupported delivery channel")

    def _send_email(self, email: str, subject: str, text: str) -> str:
        try:
            response = self.client.post(
                "https://api.resend.com/emails",
                headers={
                    "Authorization": f"Bearer {self.resend_api_key}",
                    "User-Agent": "KnowYourRights/1.0",
                },
                json={"from": self.email_from, "to": [email], "subject": subject, "text": text},
            )
            response.raise_for_status()
            return str(response.json().get("id") or f"email-{email}")
        except httpx.HTTPError as error:
            raise DeliveryError("email provider did not accept the message") from error

    def _send_sms(
        self,
        phone: str,
        body: str,
        *,
        status_callback: str | None = None,
        sender: str | None = None,
    ) -> str:
        url = "https://api.twilio.com/2010-04-01/Accounts/" f"{self.twilio_account_sid}/Messages.json"
        try:
            data = {"To": phone, "From": sender or self.twilio_from, "Body": body}
            if status_callback:
                data["StatusCallback"] = status_callback
            response = self.client.post(
                url,
                auth=(self.twilio_account_sid, self.twilio_auth_token),
                data=data,
            )
            response.raise_for_status()
            message_id = response.json().get("sid")
            if not message_id:
                raise DeliveryError("SMS provider returned no message identifier")
            return str(message_id)
        except httpx.HTTPError as error:
            raise DeliveryError("SMS provider did not accept the message") from error


def gateway_from_environment(development_mode: bool) -> DeliveryGateway:
    return DevelopmentGateway() if development_mode else ProductionGateway.from_environment()
