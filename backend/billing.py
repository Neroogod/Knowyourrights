"""Plans, entitlements, and payment providers.

The product's north star constrains this module: **authoritative rights
information for individuals is always free and complete.** Monetization sells
*convenience and depth* - higher AI question limits, business and study tooling -
never access to a person's basic rights. That rule is enforced in code: the plan
only ever changes the AI daily quota; it never gates reading a right, an emergency
scenario, or the directory.

Payments follow the same shape as `delivery.py`: a provider-agnostic gateway with
a development adapter that needs no account, and Paystack/Flutterwave adapters that
activate only when their keys are configured and otherwise fail closed. Nigerian
rails (Paystack, Flutterwave) are first-class because the audience is Nigerian.
"""

from __future__ import annotations

import hashlib
import hmac
import os
from dataclasses import dataclass
from typing import Protocol

# ------------------------------------------------------------------- plans

PLAN_FREE = "free"
PLAN_PREMIUM = "premium"  # individual
PLAN_STUDENT = "student"
PLAN_TEAM = "team"  # organisation seats (Layer 2 — deferred until org accounts exist)

VALID_PLANS = {PLAN_FREE, PLAN_PREMIUM, PLAN_STUDENT, PLAN_TEAM}

# What a plan changes. Only the AI daily quota — never content access. Prices are
# in kobo (Naira minor unit); 0 for free. Real prices are a business decision and
# are confirmed before launch.
PLAN_LIMITS: dict[str, dict] = {
    PLAN_FREE: {"ai_daily_quota": 5, "price_kobo": 0, "label": "Free"},
    PLAN_PREMIUM: {"ai_daily_quota": 100, "price_kobo": 150_000, "label": "Premium"},
    PLAN_STUDENT: {"ai_daily_quota": 100, "price_kobo": 80_000, "label": "Student"},
    PLAN_TEAM: {"ai_daily_quota": 500, "price_kobo": 1_000_000, "label": "Team"},
}

# Reads that must NEVER depend on a plan. The guardrail, named so a test can assert
# it and a future change cannot quietly paywall a right.
ALWAYS_FREE_SURFACES = (
    "topics",
    "scenarios",
    "directory",
    "search",
    "categories",
    "custody-alerts",
    "check-ins",
    "emergency-contacts",
)


def entitlements(plan: str) -> dict:
    """The limits for a plan. Unknown or lapsed plans fall back to free."""
    return PLAN_LIMITS.get(plan, PLAN_LIMITS[PLAN_FREE])


def ai_daily_quota(plan: str) -> int:
    """The AI question quota for a plan. This is the only thing money buys here."""
    return entitlements(plan)["ai_daily_quota"]


def plan_catalogue() -> list[dict]:
    """Plans for a pricing screen."""
    return [
        {
            "id": plan,
            "label": limits["label"],
            "price_kobo": limits["price_kobo"],
            "price_naira": limits["price_kobo"] // 100,
            "ai_daily_quota": limits["ai_daily_quota"],
        }
        for plan, limits in PLAN_LIMITS.items()
    ]


# ------------------------------------------------------------- payment gateways


@dataclass(frozen=True)
class CheckoutSession:
    """A started payment. `authorization_url` is where the user pays."""

    reference: str
    authorization_url: str
    provider: str


@dataclass(frozen=True)
class PaymentEvent:
    """A verified provider webhook: someone paid (or didn't)."""

    reference: str
    succeeded: bool
    plan: str
    email: str | None = None


class PaymentError(RuntimeError):
    pass


class PaymentGateway(Protocol):
    name: str

    def initialize(self, *, email: str, plan: str, reference: str) -> CheckoutSession: ...

    def verify_signature(self, *, body: bytes, signature: str) -> bool: ...

    def parse_event(self, payload: dict) -> PaymentEvent: ...


class DevelopmentPaymentGateway:
    """A no-network gateway for local development and tests.

    It returns a fake authorization URL and treats every webhook as authentic, so
    the checkout -> webhook -> activation flow can be exercised end to end without a
    merchant account.
    """

    name = "development"

    def initialize(self, *, email: str, plan: str, reference: str) -> CheckoutSession:
        return CheckoutSession(
            reference=reference,
            authorization_url=f"https://pay.example.test/checkout/{reference}",
            provider=self.name,
        )

    def verify_signature(self, *, body: bytes, signature: str) -> bool:
        return True

    def parse_event(self, payload: dict) -> PaymentEvent:
        return PaymentEvent(
            reference=payload.get("reference", ""),
            succeeded=payload.get("status") == "success",
            plan=payload.get("plan", PLAN_PREMIUM),
            email=payload.get("email"),
        )


class PaystackGateway:
    """Paystack. Live keys required; without them, construction fails closed."""

    name = "paystack"
    _INIT_URL = "https://api.paystack.co/transaction/initialize"

    def __init__(self, secret_key: str, callback_url: str) -> None:
        self._secret = secret_key
        self._callback = callback_url

    @classmethod
    def from_environment(cls) -> PaystackGateway:
        secret = os.getenv("PAYSTACK_SECRET_KEY")
        callback = os.getenv("KYR_BILLING_CALLBACK_URL")
        missing = [
            n for n, v in (("PAYSTACK_SECRET_KEY", secret), ("KYR_BILLING_CALLBACK_URL", callback)) if not v
        ]
        if missing:
            raise PaymentError(f"Paystack configuration missing: {', '.join(missing)}")
        return cls(secret, callback)

    def initialize(self, *, email: str, plan: str, reference: str) -> CheckoutSession:
        import httpx

        amount = entitlements(plan)["price_kobo"]
        response = httpx.post(
            self._INIT_URL,
            headers={"Authorization": f"Bearer {self._secret}"},
            json={
                "email": email,
                "amount": amount,
                "reference": reference,
                "callback_url": self._callback,
                "metadata": {"plan": plan},
            },
            timeout=15,
        )
        if response.status_code >= 300:
            raise PaymentError(f"Paystack initialize failed: {response.status_code}")
        data = response.json()["data"]
        return CheckoutSession(
            reference=data["reference"],
            authorization_url=data["authorization_url"],
            provider=self.name,
        )

    def verify_signature(self, *, body: bytes, signature: str) -> bool:
        expected = hmac.new(self._secret.encode(), body, hashlib.sha512).hexdigest()
        return hmac.compare_digest(expected, signature or "")

    def parse_event(self, payload: dict) -> PaymentEvent:
        data = payload.get("data", {})
        return PaymentEvent(
            reference=data.get("reference", ""),
            succeeded=payload.get("event") == "charge.success",
            plan=(data.get("metadata") or {}).get("plan", PLAN_PREMIUM),
            email=(data.get("customer") or {}).get("email"),
        )


class FlutterwaveGateway:
    """Flutterwave. Webhook authenticity is a shared secret hash header."""

    name = "flutterwave"

    def __init__(self, secret_key: str, webhook_hash: str) -> None:
        self._secret = secret_key
        self._webhook_hash = webhook_hash

    @classmethod
    def from_environment(cls) -> FlutterwaveGateway:
        secret = os.getenv("FLUTTERWAVE_SECRET_KEY")
        webhook_hash = os.getenv("FLUTTERWAVE_WEBHOOK_HASH")
        missing = [
            n
            for n, v in (("FLUTTERWAVE_SECRET_KEY", secret), ("FLUTTERWAVE_WEBHOOK_HASH", webhook_hash))
            if not v
        ]
        if missing:
            raise PaymentError(f"Flutterwave configuration missing: {', '.join(missing)}")
        return cls(secret, webhook_hash)

    def initialize(self, *, email: str, plan: str, reference: str) -> CheckoutSession:
        # Flutterwave's Standard flow is created client-side with a public key; the
        # server issues the reference and verifies the webhook. The hosted URL is
        # assembled by the client SDK, so here we return the reference to use.
        return CheckoutSession(
            reference=reference,
            authorization_url=f"flutterwave:reference:{reference}",
            provider=self.name,
        )

    def verify_signature(self, *, body: bytes, signature: str) -> bool:
        return hmac.compare_digest(self._webhook_hash, signature or "")

    def parse_event(self, payload: dict) -> PaymentEvent:
        data = payload.get("data", {})
        return PaymentEvent(
            reference=data.get("tx_ref", ""),
            succeeded=data.get("status") == "successful",
            plan=(data.get("meta") or {}).get("plan", PLAN_PREMIUM),
            email=(data.get("customer") or {}).get("email"),
        )


def gateway_from_environment(development_mode: bool) -> PaymentGateway:
    """Development gateway locally; otherwise the configured provider."""
    if development_mode:
        return DevelopmentPaymentGateway()
    provider = os.getenv("KYR_PAYMENT_PROVIDER", "paystack").lower()
    if provider == "flutterwave":
        return FlutterwaveGateway.from_environment()
    return PaystackGateway.from_environment()


if __name__ == "__main__":

    def test_free_is_the_floor_for_unknown_plans() -> None:
        assert ai_daily_quota("free") == 5
        assert ai_daily_quota("nonsense") == ai_daily_quota("free")
        assert ai_daily_quota("lapsed") == 5
        print("test_free_is_the_floor_for_unknown_plans passed")

    def test_paid_plans_only_raise_the_quota() -> None:
        # Every paid plan buys more questions, nothing else in this table.
        assert ai_daily_quota("premium") > ai_daily_quota("free")
        assert ai_daily_quota("team") >= ai_daily_quota("premium")
        keys = {k for limits in PLAN_LIMITS.values() for k in limits}
        assert keys == {
            "ai_daily_quota",
            "price_kobo",
            "label",
        }, "a plan must not be able to change anything but the AI quota"
        print("test_paid_plans_only_raise_the_quota passed")

    def test_rights_surfaces_are_declared_always_free() -> None:
        for surface in ("topics", "scenarios", "directory", "search", "custody-alerts"):
            assert surface in ALWAYS_FREE_SURFACES
        print("test_rights_surfaces_are_declared_always_free passed")

    def test_dev_gateway_round_trips_checkout_and_webhook() -> None:
        g = DevelopmentPaymentGateway()
        session = g.initialize(email="a@b.co", plan="premium", reference="ref1")
        assert session.reference == "ref1" and session.authorization_url
        assert g.verify_signature(body=b"{}", signature="anything") is True
        event = g.parse_event({"reference": "ref1", "status": "success", "plan": "premium"})
        assert event.succeeded and event.plan == "premium"
        print("test_dev_gateway_round_trips_checkout_and_webhook passed")

    def test_paystack_signature_verification() -> None:
        g = PaystackGateway("sk_test_secret", "https://cb")
        body = b'{"event":"charge.success"}'
        good = hmac.new(b"sk_test_secret", body, hashlib.sha512).hexdigest()
        assert g.verify_signature(body=body, signature=good) is True
        assert g.verify_signature(body=body, signature="tampered") is False
        print("test_paystack_signature_verification passed")

    def test_production_gateways_fail_closed_without_keys() -> None:
        for var in (
            "PAYSTACK_SECRET_KEY",
            "KYR_BILLING_CALLBACK_URL",
            "FLUTTERWAVE_SECRET_KEY",
            "FLUTTERWAVE_WEBHOOK_HASH",
        ):
            os.environ.pop(var, None)
        for factory in (PaystackGateway.from_environment, FlutterwaveGateway.from_environment):
            try:
                factory()
                raise AssertionError("expected PaymentError")
            except PaymentError:
                pass
        print("test_production_gateways_fail_closed_without_keys passed")

    test_free_is_the_floor_for_unknown_plans()
    test_paid_plans_only_raise_the_quota()
    test_rights_surfaces_are_declared_always_free()
    test_dev_gateway_round_trips_checkout_and_webhook()
    test_paystack_signature_verification()
    test_production_gateways_fail_closed_without_keys()
    print("\nAll tests passed!")
