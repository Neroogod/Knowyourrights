"""Trust and editorial operations: contribution, review, moderation, error reports.

Verified badges are only worth what the process behind them is worth. This module
is that process:

    draft -> community (visible, badged, excluded from AI) -> verified (citable)

A contributor submits; automated moderation screens the submission; a reviewer
approves, rejects, or asks for changes with notes; every state change is written
to an append-only audit log. Readers can report an error on anything, and enough
credible reports flag a record for re-review.

Two rules shape the design:

* Nothing reaches the AI without a human decision. Only `verified` records are
  retrievable, and only a reviewer can set that status.
* The audit trail cannot be rewritten. This module exposes no update or delete
  path for `AuditLogRecord`; content that fails moderation is archived, never
  silently removed.
"""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta

from sqlalchemy import DateTime, String, Text, select
from sqlalchemy.orm import Mapped, mapped_column

from backend.accounts import Base
from backend.schemas import is_stale  # the staleness rule is shared with retrieval

# ----------------------------------------------------------------- vocabulary

STATUS_DRAFT = "draft"
STATUS_COMMUNITY = "community"
STATUS_VERIFIED = "verified"
STATUS_ARCHIVED = "archived"

DECISION_APPROVE = "approve"
DECISION_REJECT = "reject"
DECISION_CHANGES = "changes"

REPORT_OPEN = "open"
REPORT_TRIAGED = "triaged"
REPORT_RESOLVED = "resolved"
REPORT_DISMISSED = "dismissed"

CONTENT_TYPES = {"topic", "scenario", "obligation", "checklist", "case", "interpretation", "directory"}

#: Reviewer/administrator may verify; contributors may only submit.
REVIEWER_ROLES = {"reviewer", "administrator"}
CONTRIBUTOR_ROLES = {"contributor", "reviewer", "administrator"}

#: Open reports needed before a record is flagged for re-review.
FLAG_THRESHOLD = 3
#: Submissions allowed per contributor per hour.
SUBMISSION_LIMIT_PER_HOUR = 10

#: Phrases that suggest proprietary law-report text has been pasted in. Report
#: headnotes are licensed material and must never be republished.
PROPRIETARY_MARKERS = (
    "nwlr",
    "all fwlr",
    "weekly law report",
    "headnote",
    "law report",
)


class ReviewError(ValueError):
    """Raised when a caller is not permitted to do something, or input is invalid."""


# --------------------------------------------------------------------- models


class ContributionRecord(Base):
    """A submitted piece of content moving through the trust pipeline."""

    __tablename__ = "contributions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    author_user_id: Mapped[str] = mapped_column(String(36), index=True)
    content_type: Mapped[str] = mapped_column(String(24), index=True)
    title: Mapped[str] = mapped_column(String(300))
    payload_json: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(24), index=True)
    moderation_flags: Mapped[str] = mapped_column(String(500), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ReviewRecord(Base):
    """A reviewer's decision on a contribution, with their notes and attribution."""

    __tablename__ = "content_reviews"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    contribution_id: Mapped[str] = mapped_column(String(36), index=True)
    reviewer_user_id: Mapped[str] = mapped_column(String(36), index=True)
    decision: Mapped[str] = mapped_column(String(16), index=True)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ErrorReportRecord(Base):
    """A reader's report that something is wrong with a piece of content."""

    __tablename__ = "error_reports"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    target_type: Mapped[str] = mapped_column(String(24), index=True)
    target_id: Mapped[str] = mapped_column(String(120), index=True)
    reporter_user_id: Mapped[str | None] = mapped_column(String(36), index=True)
    message: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(16), index=True)
    resolution: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AuditLogRecord(Base):
    """Append-only trail of every trust decision. Never updated or deleted."""

    __tablename__ = "content_audit_log"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    actor_user_id: Mapped[str | None] = mapped_column(String(36), index=True)
    action: Mapped[str] = mapped_column(String(48), index=True)
    target_type: Mapped[str] = mapped_column(String(24), index=True)
    target_id: Mapped[str] = mapped_column(String(120), index=True)
    before_json: Mapped[str | None] = mapped_column(Text)
    after_json: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


# ------------------------------------------------------------------ moderation


@dataclass(frozen=True)
class ModerationResult:
    """Automated screening applied before a human ever sees a submission."""

    flags: tuple[str, ...]

    @property
    def blocked(self) -> bool:
        """Suspected copyright infringement is held back rather than published."""
        return "possible-proprietary-copy" in self.flags


def _tokens(text: str) -> set[str]:
    flattened = "".join(c.lower() if c.isalnum() else " " for c in text)
    return {word for word in flattened.split() if len(word) > 3}


def screen_submission(
    payload: dict,
    existing_texts: list[str] | None = None,
    content_type: str = "topic",
) -> ModerationResult:
    """Screen a submission for missing citations, copied report text, and duplicates.

    This is a first pass, not a substitute for the reviewer: it exists so obvious
    problems never reach the queue and so licensing risk is caught before publish.
    """
    flags: list[str] = []
    body = " ".join(
        str(value)
        for key, value in payload.items()
        if key not in {"citations"} and isinstance(value, str)
    )

    # A directory entry is a contact, not a legal claim, so it needs no citation;
    # every other content type asserts law and must carry one.
    if content_type != "directory" and not payload.get("citations"):
        flags.append("missing-citation")

    lowered = body.lower()
    if any(marker in lowered for marker in PROPRIETARY_MARKERS):
        flags.append("possible-proprietary-copy")

    body_tokens = _tokens(body)
    for existing in existing_texts or []:
        other = _tokens(existing)
        if not body_tokens or not other:
            continue
        overlap = len(body_tokens & other) / len(body_tokens)
        if overlap >= 0.9:
            flags.append("possible-duplicate")
            break

    return ModerationResult(tuple(flags))


# -------------------------------------------------------------------- service


class ReviewService:
    """Trust operations over the accounts database.

    Takes an `AccountService` for its session factory and role lookup so
    permissions come from one place.
    """

    def __init__(self, accounts) -> None:
        self._accounts = accounts
        self.sessions = accounts.sessions

    # -- helpers ---------------------------------------------------------

    @staticmethod
    def _now() -> datetime:
        return datetime.now(UTC)

    def _require(self, user_id: str, allowed: set[str]) -> str:
        role = self._accounts.role(user_id)
        if role not in allowed:
            raise ReviewError(f"requires one of: {', '.join(sorted(allowed))}")
        return role

    def _audit(self, session, actor: str | None, action: str, target_type: str,
               target_id: str, before: dict | None, after: dict | None) -> None:
        session.add(
            AuditLogRecord(
                id=str(uuid.uuid4()),
                actor_user_id=actor,
                action=action,
                target_type=target_type,
                target_id=target_id,
                before_json=json.dumps(before) if before is not None else None,
                after_json=json.dumps(after) if after is not None else None,
                created_at=self._now(),
            )
        )

    # -- contributions ---------------------------------------------------

    def submit(self, author_id: str, content_type: str, title: str, payload: dict) -> dict:
        """Submit content. Passes moderation into `community`, otherwise held as `draft`."""
        self._require(author_id, CONTRIBUTOR_ROLES)
        if content_type not in CONTENT_TYPES:
            raise ReviewError(f"unknown content type: {content_type}")
        if not title.strip():
            raise ReviewError("a title is required")

        now = self._now()
        with self.sessions.begin() as session:
            recent = session.scalars(
                select(ContributionRecord).where(
                    ContributionRecord.author_user_id == author_id,
                    ContributionRecord.created_at >= now - timedelta(hours=1),
                )
            ).all()
            if len(recent) >= SUBMISSION_LIMIT_PER_HOUR:
                raise ReviewError("submission rate limit reached; try again later")

            existing = session.scalars(
                select(ContributionRecord.payload_json).where(
                    ContributionRecord.content_type == content_type
                )
            ).all()
            result = screen_submission(payload, list(existing), content_type)

            # Clean submissions become community content immediately: visible and
            # badged, but never retrievable until a reviewer verifies them.
            status = STATUS_DRAFT if result.flags else STATUS_COMMUNITY
            record = ContributionRecord(
                id=str(uuid.uuid4()),
                author_user_id=author_id,
                content_type=content_type,
                title=title.strip(),
                payload_json=json.dumps(payload),
                status=status,
                moderation_flags=",".join(result.flags),
                created_at=now,
                updated_at=now,
            )
            session.add(record)
            self._audit(session, author_id, "contribution.submitted", content_type, record.id,
                        None, {"status": status, "flags": list(result.flags)})
            return _contribution_dict(record)

    def queue(self, reviewer_id: str, status: str = STATUS_COMMUNITY, limit: int = 50) -> list[dict]:
        """The reviewer's work queue."""
        self._require(reviewer_id, REVIEWER_ROLES)
        with self.sessions() as session:
            rows = session.scalars(
                select(ContributionRecord)
                .where(ContributionRecord.status == status)
                .order_by(ContributionRecord.created_at)
                .limit(limit)
            ).all()
            return [_contribution_dict(r) for r in rows]

    def decide(self, reviewer_id: str, contribution_id: str, decision: str,
               notes: str | None = None) -> dict:
        """Approve, reject, or request changes. Only a reviewer can verify content."""
        self._require(reviewer_id, REVIEWER_ROLES)
        if decision not in {DECISION_APPROVE, DECISION_REJECT, DECISION_CHANGES}:
            raise ReviewError("invalid decision")
        if decision != DECISION_APPROVE and not (notes or "").strip():
            raise ReviewError("notes are required when rejecting or requesting changes")

        with self.sessions.begin() as session:
            record = session.get(ContributionRecord, contribution_id)
            if record is None:
                raise ReviewError("contribution not found")
            if record.author_user_id == reviewer_id:
                raise ReviewError("a contributor cannot review their own submission")

            flags = [f for f in record.moderation_flags.split(",") if f]
            if decision == DECISION_APPROVE and "possible-proprietary-copy" in flags:
                raise ReviewError(
                    "cannot verify content flagged as a possible proprietary copy; "
                    "clear the licensing flag first"
                )

            before = {"status": record.status}
            record.status = {
                DECISION_APPROVE: STATUS_VERIFIED,
                DECISION_REJECT: STATUS_ARCHIVED,
                DECISION_CHANGES: STATUS_DRAFT,
            }[decision]
            record.updated_at = self._now()

            session.add(
                ReviewRecord(
                    id=str(uuid.uuid4()),
                    contribution_id=contribution_id,
                    reviewer_user_id=reviewer_id,
                    decision=decision,
                    notes=notes,
                    created_at=self._now(),
                )
            )
            self._audit(session, reviewer_id, f"contribution.{decision}", record.content_type,
                        contribution_id, before, {"status": record.status})
            return _contribution_dict(record)

    def reviews_for(self, contribution_id: str) -> list[dict]:
        """Decision history for one contribution."""
        with self.sessions() as session:
            rows = session.scalars(
                select(ReviewRecord)
                .where(ReviewRecord.contribution_id == contribution_id)
                .order_by(ReviewRecord.created_at)
            ).all()
            return [
                {
                    "id": r.id,
                    "reviewer_user_id": r.reviewer_user_id,
                    "decision": r.decision,
                    "notes": r.notes,
                    "created_at": r.created_at.isoformat(),
                }
                for r in rows
            ]

    def contributor_profile(self, user_id: str) -> dict:
        """What a contributor has submitted and how it fared.

        Attribution is part of the incentive to contribute well, so accepted work
        is counted and shown back to the person who did it.
        """
        with self.sessions() as session:
            rows = session.scalars(
                select(ContributionRecord)
                .where(ContributionRecord.author_user_id == user_id)
                .order_by(ContributionRecord.created_at.desc())
            ).all()
        counts: dict[str, int] = {}
        for row in rows:
            counts[row.status] = counts.get(row.status, 0) + 1
        return {
            "user_id": user_id,
            "submitted": len(rows),
            "by_status": counts,
            "verified": counts.get(STATUS_VERIFIED, 0),
            "awaiting_review": counts.get(STATUS_COMMUNITY, 0),
            "contributions": [_contribution_dict(r) for r in rows[:50]],
        }

    # -- error reports ---------------------------------------------------

    def report_error(self, target_type: str, target_id: str, message: str,
                     reporter_user_id: str | None = None) -> dict:
        """Anyone, signed in or not, can report an error. Reporting is never gated."""
        if not message.strip():
            raise ReviewError("describe what is wrong")
        if len(message) > 4000:
            raise ReviewError("report is too long")

        with self.sessions.begin() as session:
            record = ErrorReportRecord(
                id=str(uuid.uuid4()),
                target_type=target_type,
                target_id=target_id,
                reporter_user_id=reporter_user_id,
                message=message.strip(),
                status=REPORT_OPEN,
                created_at=self._now(),
            )
            session.add(record)
            session.flush()
            open_count = len(
                session.scalars(
                    select(ErrorReportRecord.id).where(
                        ErrorReportRecord.target_type == target_type,
                        ErrorReportRecord.target_id == target_id,
                        ErrorReportRecord.status.in_([REPORT_OPEN, REPORT_TRIAGED]),
                    )
                ).all()
            )
            flagged = open_count >= FLAG_THRESHOLD
            self._audit(session, reporter_user_id, "error.reported", target_type, target_id,
                        None, {"open_reports": open_count, "flagged": flagged})
            return {
                "id": record.id,
                "status": record.status,
                "open_reports": open_count,
                "flagged_for_review": flagged,
            }

    def error_queue(self, reviewer_id: str, status: str = REPORT_OPEN, limit: int = 100) -> list[dict]:
        """Triage queue, oldest first so nothing is left to rot."""
        self._require(reviewer_id, REVIEWER_ROLES)
        with self.sessions() as session:
            rows = session.scalars(
                select(ErrorReportRecord)
                .where(ErrorReportRecord.status == status)
                .order_by(ErrorReportRecord.created_at)
                .limit(limit)
            ).all()
            return [_report_dict(r) for r in rows]

    def flagged_targets(self, reviewer_id: str) -> list[dict]:
        """Records with enough open reports to warrant re-review."""
        self._require(reviewer_id, REVIEWER_ROLES)
        with self.sessions() as session:
            rows = session.scalars(
                select(ErrorReportRecord).where(
                    ErrorReportRecord.status.in_([REPORT_OPEN, REPORT_TRIAGED])
                )
            ).all()
        counts: dict[tuple[str, str], int] = {}
        for row in rows:
            counts[(row.target_type, row.target_id)] = counts.get((row.target_type, row.target_id), 0) + 1
        return [
            {"target_type": t, "target_id": i, "open_reports": n}
            for (t, i), n in sorted(counts.items(), key=lambda kv: -kv[1])
            if n >= FLAG_THRESHOLD
        ]

    def resolve_error(self, reviewer_id: str, report_id: str, status: str,
                      resolution: str | None = None) -> dict:
        """Close out a report with an explicit outcome."""
        self._require(reviewer_id, REVIEWER_ROLES)
        if status not in {REPORT_TRIAGED, REPORT_RESOLVED, REPORT_DISMISSED}:
            raise ReviewError("invalid report status")
        with self.sessions.begin() as session:
            record = session.get(ErrorReportRecord, report_id)
            if record is None:
                raise ReviewError("report not found")
            before = {"status": record.status}
            record.status = status
            record.resolution = resolution
            record.resolved_at = self._now() if status != REPORT_TRIAGED else None
            self._audit(session, reviewer_id, f"error.{status}", record.target_type,
                        record.target_id, before, {"status": status})
            return _report_dict(record)

    # -- audit -----------------------------------------------------------

    def audit_trail(self, actor_id: str, limit: int = 200,
                    target_id: str | None = None) -> list[dict]:
        """Read the append-only trail. Administrators only; there is no write path."""
        self._require(actor_id, {"administrator"})
        with self.sessions() as session:
            query = select(AuditLogRecord).order_by(AuditLogRecord.created_at.desc()).limit(limit)
            if target_id:
                query = (
                    select(AuditLogRecord)
                    .where(AuditLogRecord.target_id == target_id)
                    .order_by(AuditLogRecord.created_at.desc())
                    .limit(limit)
                )
            rows = session.scalars(query).all()
            return [
                {
                    "id": r.id,
                    "actor_user_id": r.actor_user_id,
                    "action": r.action,
                    "target_type": r.target_type,
                    "target_id": r.target_id,
                    "before": json.loads(r.before_json) if r.before_json else None,
                    "after": json.loads(r.after_json) if r.after_json else None,
                    "created_at": r.created_at.isoformat(),
                }
                for r in rows
            ]

    # -- staleness -------------------------------------------------------

    def stale_content(self, reviewer_id: str, pack, today: date | None = None) -> list[dict]:
        """Published content whose scheduled review date has passed.

        These records are already excluded from retrieval; this lists them so a
        reviewer can renew or correct them.
        """
        self._require(reviewer_id, REVIEWER_ROLES)
        stale: list[dict] = []
        groups = (
            ("topic", getattr(pack, "topics", [])),
            ("scenario", getattr(pack, "scenarios", [])),
            ("obligation", getattr(pack, "obligations", [])),
            ("case", getattr(pack, "cases", [])),
        )
        for kind, items in groups:
            for item in items:
                due = getattr(item, "review_due_at", None)
                status = getattr(item, "status", None)
                status_value = getattr(status, "value", status)
                if status_value == STATUS_VERIFIED and is_stale(due, today):
                    stale.append(
                        {
                            "target_type": kind,
                            "target_id": item.id,
                            "title": getattr(item, "title", getattr(item, "trigger", item.id)),
                            "review_due_at": due,
                            "reviewed_by": getattr(item, "reviewed_by", None),
                        }
                    )
        return stale


def _contribution_dict(record: ContributionRecord) -> dict:
    return {
        "id": record.id,
        "author_user_id": record.author_user_id,
        "content_type": record.content_type,
        "title": record.title,
        "payload": json.loads(record.payload_json),
        "status": record.status,
        "moderation_flags": [f for f in record.moderation_flags.split(",") if f],
        "created_at": record.created_at.isoformat(),
        "updated_at": record.updated_at.isoformat(),
    }


def _report_dict(record: ErrorReportRecord) -> dict:
    return {
        "id": record.id,
        "target_type": record.target_type,
        "target_id": record.target_id,
        "reporter_user_id": record.reporter_user_id,
        "message": record.message,
        "status": record.status,
        "resolution": record.resolution,
        "created_at": record.created_at.isoformat(),
        "resolved_at": record.resolved_at.isoformat() if record.resolved_at else None,
    }
