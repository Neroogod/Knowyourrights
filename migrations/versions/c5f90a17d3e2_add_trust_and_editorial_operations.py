"""add trust and editorial operations

Contribution pipeline (draft -> community -> verified), reviewer decisions with
notes, reader error reports and their triage queue, and an append-only audit log
of every trust decision.

Revision ID: c5f90a17d3e2
Revises: b8e21f34a6d0
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "c5f90a17d3e2"
down_revision: str | Sequence[str] | None = "b8e21f34a6d0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "contributions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("author_user_id", sa.String(length=36), nullable=False),
        sa.Column("content_type", sa.String(length=24), nullable=False),
        sa.Column("title", sa.String(length=300), nullable=False),
        sa.Column("payload_json", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("moderation_flags", sa.String(length=500), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_contributions_author_user_id", "contributions", ["author_user_id"])
    op.create_index("ix_contributions_content_type", "contributions", ["content_type"])
    op.create_index("ix_contributions_status", "contributions", ["status"])

    op.create_table(
        "content_reviews",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("contribution_id", sa.String(length=36), nullable=False),
        sa.Column("reviewer_user_id", sa.String(length=36), nullable=False),
        sa.Column("decision", sa.String(length=16), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_content_reviews_contribution_id", "content_reviews", ["contribution_id"])
    op.create_index("ix_content_reviews_reviewer_user_id", "content_reviews", ["reviewer_user_id"])
    op.create_index("ix_content_reviews_decision", "content_reviews", ["decision"])

    op.create_table(
        "error_reports",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("target_type", sa.String(length=24), nullable=False),
        sa.Column("target_id", sa.String(length=120), nullable=False),
        sa.Column("reporter_user_id", sa.String(length=36), nullable=True),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("resolution", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_error_reports_target_type", "error_reports", ["target_type"])
    op.create_index("ix_error_reports_target_id", "error_reports", ["target_id"])
    op.create_index("ix_error_reports_reporter_user_id", "error_reports", ["reporter_user_id"])
    op.create_index("ix_error_reports_status", "error_reports", ["status"])
    op.create_index("ix_error_reports_created_at", "error_reports", ["created_at"])
    # The triage queue is "oldest open report first", so index the pair it sorts on.
    op.create_index("ix_error_reports_queue", "error_reports", ["status", "created_at"])

    op.create_table(
        "content_audit_log",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("actor_user_id", sa.String(length=36), nullable=True),
        sa.Column("action", sa.String(length=48), nullable=False),
        sa.Column("target_type", sa.String(length=24), nullable=False),
        sa.Column("target_id", sa.String(length=120), nullable=False),
        sa.Column("before_json", sa.Text(), nullable=True),
        sa.Column("after_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_content_audit_log_actor_user_id", "content_audit_log", ["actor_user_id"])
    op.create_index("ix_content_audit_log_action", "content_audit_log", ["action"])
    op.create_index("ix_content_audit_log_target_type", "content_audit_log", ["target_type"])
    op.create_index("ix_content_audit_log_target_id", "content_audit_log", ["target_id"])
    op.create_index("ix_content_audit_log_created_at", "content_audit_log", ["created_at"])

    # Scheduled review dates drive automatic removal from AI retrieval. Only
    # obligations carried one before; every citable record needs it.
    for table in ("content_topics", "content_scenarios", "content_cases"):
        op.add_column(table, sa.Column("review_due_at", sa.DateTime(timezone=True), nullable=True))
        op.create_index(f"ix_{table}_review_due_at", table, ["review_due_at"])


def downgrade() -> None:
    for table in ("content_topics", "content_scenarios", "content_cases"):
        op.drop_index(f"ix_{table}_review_due_at", table_name=table)
        op.drop_column(table, "review_due_at")
    op.drop_table("content_audit_log")
    op.drop_table("error_reports")
    op.drop_table("content_reviews")
    op.drop_table("contributions")
