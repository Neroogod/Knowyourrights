"""Data retention enforcement and localization staleness.

Retention is only real if data actually disappears on schedule; these tests put
rows behind the cutoff and prove the purge deletes them, while leaving the audit
log and content alone. The localization tests prove a translation is flagged
stale the moment its source text drifts, so a stale translation cannot masquerade
as current law.
"""

import uuid
from datetime import timedelta

import pytest

from backend.accounts import (
    AbuseEventRecord,
    AccountService,
    AIUsageRecord,
    DevelopmentGateway,
    VerificationRecord,
)
from backend.retention import (
    RETENTION_DAYS,
    RETENTION_EXEMPT,
    RETENTION_SCHEDULE,
    run_retention_purge,
    schedule_as_table,
)
from backend.schemas import (
    Status,
    Topic,
    source_fingerprint,
    translation_is_stale,
)


@pytest.fixture
def accounts() -> AccountService:
    return AccountService("sqlite+pysqlite:///:memory:", secret="x" * 32, gateway=DevelopmentGateway())


# --------------------------------------------------------------- retention


def test_schedule_and_docs_agree():
    # The dict the code enforces is derived from the documented schedule.
    assert set(RETENTION_DAYS) == {r.data_class for r in RETENTION_SCHEDULE}
    assert {row["data_class"] for row in schedule_as_table()} == set(RETENTION_DAYS)


def test_location_is_the_shortest_lived_class():
    assert RETENTION_DAYS["custody_alert_location"] == 0
    assert RETENTION_DAYS["custody_alert_location"] <= min(
        RETENTION_DAYS[c] for c in ("ai_usage_telemetry", "abuse_events", "webhook_events")
    )


def test_audit_log_and_content_are_exempt():
    assert "content_audit_log" in RETENTION_EXEMPT
    assert "versioned_content" in RETENTION_EXEMPT


def test_purge_deletes_expired_telemetry_and_keeps_recent(accounts: AccountService):
    now = accounts._now()
    old = now - timedelta(days=RETENTION_DAYS["ai_usage_telemetry"] + 5)
    with accounts.sessions.begin() as session:
        session.add(
            AIUsageRecord(
                id=str(uuid.uuid4()),
                privacy_id="p",
                user_id=None,
                corpus="rights",
                jurisdiction="NG-Federal",
                model_key="m",
                latency_ms=1,
                estimated_cost_usd=0.0,
                created_at=old,
            )
        )
        session.add(
            AIUsageRecord(
                id=str(uuid.uuid4()),
                privacy_id="p",
                user_id=None,
                corpus="rights",
                jurisdiction="NG-Federal",
                model_key="m",
                latency_ms=1,
                estimated_cost_usd=0.0,
                created_at=now,
            )
        )
    deleted = accounts.purge_retention(RETENTION_DAYS)
    assert deleted >= 1
    with accounts.sessions() as session:
        remaining = session.query(AIUsageRecord).count()
    assert remaining == 1, "the recent event must survive, the old one must not"


def test_purge_deletes_expired_abuse_and_verification(accounts: AccountService):
    now = accounts._now()
    with accounts.sessions.begin() as session:
        session.add(
            AbuseEventRecord(
                id=str(uuid.uuid4()),
                key_hash="k",
                occurred_at=now - timedelta(days=RETENTION_DAYS["abuse_events"] + 1),
            )
        )
        session.add(
            VerificationRecord(
                id=str(uuid.uuid4()),
                subject_id="s",
                purpose="email",
                token_hash="t",
                expires_at=now - timedelta(days=RETENTION_DAYS["verification_tokens"] + 1),
            )
        )
    accounts.purge_retention(RETENTION_DAYS)
    with accounts.sessions() as session:
        assert session.query(AbuseEventRecord).count() == 0
        assert session.query(VerificationRecord).count() == 0


def test_purge_is_idempotent(accounts: AccountService):
    assert accounts.purge_retention(RETENTION_DAYS) == 0
    assert run_retention_purge(accounts)["custody_alert_location"] == 0


# ------------------------------------------------------------ localization


def test_new_content_defaults_to_english():
    topic = Topic(
        id="t",
        title="T",
        category="c",
        jurisdiction="NG",
        summary="s",
        body_plain="b",
        status=Status.verified,
        reviewed_by="L",
        citations=[{"source_name": "1999 Constitution", "locator": "s.35"}],
    )
    assert topic.language == "en"
    assert topic.translation_of is None


def test_a_translation_links_to_its_source():
    pcm = Topic(
        id="rights-when-arrested__pcm",
        title="Your rights wen dem arrest you",
        category="arrest-and-police",
        jurisdiction="NG-Federal",
        summary="Talk small, wait for your lawyer.",
        body_plain="...",
        language="pcm",
        translation_of="rights-when-arrested",
        status=Status.draft,
    )
    assert pcm.language == "pcm"
    assert pcm.translation_of == "rights-when-arrested"
    # A draft translation needs no citation; it inherits the source's authority
    # only once reviewed and promoted.
    assert pcm.status == Status.draft


def test_translation_goes_stale_when_the_source_changes():
    source_v1 = source_fingerprint("Your rights when arrested", "Stay silent until a lawyer.")
    # Translated against v1.
    assert translation_is_stale(source_v1, source_v1) is False
    # The source is edited.
    source_v2 = source_fingerprint("Your rights when arrested", "Stay silent until you see a lawyer.")
    assert translation_is_stale(source_v1, source_v2) is True


def test_untranslated_record_is_never_stale():
    # A canonical English record has no source hash and can't be a stale translation.
    assert translation_is_stale(None, source_fingerprint("anything")) is False


def test_fingerprint_is_stable_and_order_sensitive():
    assert source_fingerprint("a", "b") == source_fingerprint("a", "b")
    assert source_fingerprint("a", "b") != source_fingerprint("b", "a")
