"""add AI cache, usage telemetry, and human review queue

Revision ID: b8e21f34a6d0
Revises: 7a1c3e9d52f4
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "b8e21f34a6d0"
down_revision: str | Sequence[str] | None = "7a1c3e9d52f4"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "ai_answer_cache",
        sa.Column("cache_key", sa.String(length=64), primary_key=True),
        sa.Column("response_json", sa.String(length=24000), nullable=False),
        sa.Column("content_version", sa.Integer(), nullable=False),
        sa.Column("model_key", sa.String(length=255), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("hits", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_ai_answer_cache_expires_at", "ai_answer_cache", ["expires_at"])
    op.create_table(
        "ai_usage_events",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("privacy_id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.String(length=36)),
        sa.Column("corpus", sa.String(length=24), nullable=False),
        sa.Column("jurisdiction", sa.String(length=80), nullable=False),
        sa.Column("model_key", sa.String(length=255), nullable=False),
        sa.Column("latency_ms", sa.Integer(), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False),
        sa.Column("output_tokens", sa.Integer(), nullable=False),
        sa.Column("estimated_cost_usd", sa.Float(), nullable=False),
        sa.Column("cache_hit", sa.Boolean(), nullable=False),
        sa.Column("refused", sa.Boolean(), nullable=False),
        sa.Column("sampled_for_review", sa.Boolean(), nullable=False),
        sa.Column("response_json", sa.String(length=24000)),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    for column in (
        "privacy_id",
        "user_id",
        "corpus",
        "jurisdiction",
        "sampled_for_review",
        "created_at",
    ):
        op.create_index(f"ix_ai_usage_events_{column}", "ai_usage_events", [column])
    op.create_table(
        "ai_answer_reviews",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("usage_event_id", sa.String(length=36), nullable=False, unique=True),
        sa.Column("reviewer_user_id", sa.String(length=36), nullable=False),
        sa.Column("verdict", sa.String(length=24), nullable=False),
        sa.Column("notes", sa.String(length=4000)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["usage_event_id"], ["ai_usage_events.id"]),
    )
    op.create_index(
        "ix_ai_answer_reviews_usage_event_id",
        "ai_answer_reviews",
        ["usage_event_id"],
        unique=True,
    )
    op.create_index(
        "ix_ai_answer_reviews_reviewer_user_id",
        "ai_answer_reviews",
        ["reviewer_user_id"],
    )
    op.create_index(
        "ix_ai_answer_reviews_verdict", "ai_answer_reviews", ["verdict"]
    )


def downgrade() -> None:
    op.drop_table("ai_answer_reviews")
    op.drop_table("ai_usage_events")
    op.drop_table("ai_answer_cache")
