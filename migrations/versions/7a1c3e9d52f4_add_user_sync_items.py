"""add saved-content and draft sync records

Revision ID: 7a1c3e9d52f4
Revises: 4d2f7b8a91c0
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "7a1c3e9d52f4"
down_revision: str | Sequence[str] | None = "4d2f7b8a91c0"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "user_sync_items",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("kind", sa.String(20), nullable=False),
        sa.Column("item_id", sa.String(160), nullable=False),
        sa.Column("payload_json", sa.String(12000), nullable=False),
        sa.Column("deleted", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "kind", "item_id", name="uq_user_sync_item"),
    )
    op.create_index("ix_user_sync_items_user_id", "user_sync_items", ["user_id"])
    op.create_index("ix_user_sync_items_kind", "user_sync_items", ["kind"])
    op.create_index("ix_user_sync_items_updated_at", "user_sync_items", ["updated_at"])


def downgrade() -> None:
    op.drop_index("ix_user_sync_items_updated_at", table_name="user_sync_items")
    op.drop_index("ix_user_sync_items_kind", table_name="user_sync_items")
    op.drop_index("ix_user_sync_items_user_id", table_name="user_sync_items")
    op.drop_table("user_sync_items")
