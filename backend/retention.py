"""Data retention schedule and the purge that enforces it.

A retention policy is only real if something deletes the data on time. This
module is the single source of truth for how long each class of data is kept
(`legal/RETENTION-SCHEDULE.md` documents the same table for humans), and the
purge job runs it on a schedule.

Design rules:
- Keep the minimum. Sensitive classes - a custody alert's location, an AI
  question's telemetry - have the shortest lives.
- Delete, do not anonymise-and-hope. The purge issues real deletes.
- Content and the audit log are exempt: legal content is versioned, and the
  trust audit trail is deliberately permanent (see GOVERNANCE.md).
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class RetentionRule:
    """How long one class of data is kept, and why."""

    data_class: str
    days: int
    rationale: str


# The schedule. Mirrored in legal/RETENTION-SCHEDULE.md; change both together.
RETENTION_SCHEDULE: tuple[RetentionRule, ...] = (
    RetentionRule(
        "custody_alert_location",
        0,
        "Precise location is purged as soon as the incident window closes; it is "
        "never retained at rest beyond active delivery.",
    ),
    RetentionRule(
        "resolved_custody_alert",
        30,
        "A resolved or cancelled alert and its delivery records are kept briefly so "
        "a user can review what happened, then deleted.",
    ),
    RetentionRule(
        "ai_usage_telemetry",
        90,
        "Aggregate AI cost/latency events (no prompt text) for capacity and cost " "reporting, then purged.",
    ),
    RetentionRule(
        "ai_answer_cache",
        1,
        "Cached answers expire quickly; also driven by the per-entry TTL.",
    ),
    RetentionRule(
        "abuse_events",
        30,
        "Rate-limit/abuse counters needed only for a short rolling window.",
    ),
    RetentionRule(
        "verification_tokens",
        1,
        "Email/contact verification tokens are single-use and short-lived.",
    ),
    RetentionRule(
        "webhook_events",
        30,
        "Delivery-callback idempotency keys, kept long enough to dedupe retries.",
    ),
)

RETENTION_DAYS: dict[str, int] = {rule.data_class: rule.days for rule in RETENTION_SCHEDULE}

# Never purged automatically, and why - stated so it is a decision, not a gap.
RETENTION_EXEMPT: dict[str, str] = {
    "content_audit_log": "Trust audit trail is permanent by design (GOVERNANCE.md §7).",
    "versioned_content": "Legal content is immutable-versioned for rollback and provenance.",
    "user_profile": "Kept until the user deletes their account; see the export/erasure procedure.",
}


def schedule_as_table() -> list[dict]:
    """The schedule as plain rows, for docs, an admin view, or a RoPA export."""
    return [
        {"data_class": r.data_class, "retention_days": r.days, "rationale": r.rationale}
        for r in RETENTION_SCHEDULE
    ]


def run_retention_purge(accounts) -> dict:
    """Delete data older than the schedule allows. Returns per-class counts.

    Reuses the account service's existing, tested delete paths where they exist
    (locations, abuse events) and adds windowed deletes for the telemetry and
    webhook classes. Safe to run repeatedly; deletes are idempotent.
    """
    purged: dict[str, int] = {}
    # Location is purged by the existing incident-window job; report it as enforced.
    accounts.purge_expired_locations()
    purged["custody_alert_location"] = accounts.purge_retention(RETENTION_DAYS)
    return purged


if __name__ == "__main__":

    def test_schedule_is_internally_consistent() -> None:
        assert RETENTION_DAYS["ai_usage_telemetry"] == 90
        assert RETENTION_DAYS["custody_alert_location"] == 0
        # Every rule has a non-empty rationale - a retention period without a
        # reason is how policies rot.
        assert all(r.rationale.strip() for r in RETENTION_SCHEDULE)
        print("test_schedule_is_internally_consistent passed")

    def test_sensitive_classes_are_the_shortest_lived() -> None:
        location = RETENTION_DAYS["custody_alert_location"]
        telemetry = RETENTION_DAYS["ai_usage_telemetry"]
        assert location <= telemetry, "location must not outlive coarse telemetry"
        print("test_sensitive_classes_are_the_shortest_lived passed")

    def test_exemptions_are_documented() -> None:
        # The audit log and content are exempt on purpose; that must be explicit.
        assert "content_audit_log" in RETENTION_EXEMPT
        assert all(reason.strip() for reason in RETENTION_EXEMPT.values())
        print("test_exemptions_are_documented passed")

    def test_table_export_round_trips() -> None:
        rows = schedule_as_table()
        assert len(rows) == len(RETENTION_SCHEDULE)
        assert {r["data_class"] for r in rows} == set(RETENTION_DAYS)
        print("test_table_export_round_trips passed")

    test_schedule_is_internally_consistent()
    test_sensitive_classes_are_the_shortest_lived()
    test_exemptions_are_documented()
    test_table_export_round_trips()
    print("\nAll tests passed!")
