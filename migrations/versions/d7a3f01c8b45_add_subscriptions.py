"""add subscriptions

Paid plans. Absence of an active row means the free plan; a plan only ever raises
the AI question quota and never gates content (backend/billing.py).

Revision ID: d7a3f01c8b45
Revises: c5f90a17d3e2
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "d7a3f01c8b45"
down_revision: str | Sequence[str] | None = "c5f90a17d3e2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "subscriptions",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("subject_type", sa.String(length=16), nullable=False, server_default="user"),
        sa.Column("subject_id", sa.String(length=36), nullable=False),
        sa.Column("plan", sa.String(length=20), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("provider", sa.String(length=20), nullable=False),
        sa.Column("provider_reference", sa.String(length=120), nullable=False),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_subscriptions_subject_id", "subscriptions", ["subject_id"])
    op.create_index("ix_subscriptions_status", "subscriptions", ["status"])
    op.create_index(
        "ix_subscriptions_provider_reference",
        "subscriptions",
        ["provider_reference"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_subscriptions_provider_reference", table_name="subscriptions")
    op.drop_index("ix_subscriptions_status", table_name="subscriptions")
    op.drop_index("ix_subscriptions_subject_id", table_name="subscriptions")
    op.drop_table("subscriptions")
