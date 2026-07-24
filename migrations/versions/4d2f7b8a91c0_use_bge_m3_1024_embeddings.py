"""use BGE-M3 1024-dimensional embeddings

Revision ID: 4d2f7b8a91c0
Revises: 90c6bc3a82b9
Create Date: 2026-07-23

Changing vector dimensions requires re-embedding. Existing vectors are deliberately
invalidated while model history remains available for audit.
"""

from collections.abc import Sequence

from alembic import op

revision: str = "4d2f7b8a91c0"
down_revision: str | Sequence[str] | None = "90c6bc3a82b9"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def resize(dimensions: int) -> None:
    if op.get_bind().dialect.name != "postgresql":
        return
    op.execute("DROP INDEX IF EXISTS ix_content_chunks_embedding_hnsw")
    op.execute(
        "UPDATE content_chunks SET embedding = NULL, embedding_model_id = NULL, embedded_at = NULL"
    )
    op.execute(
        f"ALTER TABLE content_chunks ALTER COLUMN embedding TYPE vector({dimensions}) "
        "USING NULL"
    )
    op.execute(
        "CREATE INDEX ix_content_chunks_embedding_hnsw ON content_chunks "
        "USING hnsw (embedding vector_cosine_ops) WHERE status = 'verified'"
    )


def upgrade() -> None:
    resize(1024)


def downgrade() -> None:
    resize(1536)
