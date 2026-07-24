import json
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, select

from backend.content_db import (
    ChunkRecord,
    ContentVersionRecord,
    DatabaseContentRepository,
)
from backend.schemas import ContentPack

ROOT = Path(__file__).resolve().parents[2]


def migrated_database(tmp_path: Path) -> str:
    database_url = f"sqlite:///{tmp_path / 'content.db'}"
    config = Config(str(ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(ROOT / "migrations"))
    config.set_main_option("sqlalchemy.url", database_url)
    command.upgrade(config, "head")
    return database_url


def content_pack() -> ContentPack:
    return ContentPack.model_validate(
        json.loads((ROOT / "data" / "content_pack.json").read_text(encoding="utf-8"))
    )


def test_initial_migration_builds_account_and_content_schema(tmp_path: Path) -> None:
    url = migrated_database(tmp_path)
    tables = set(inspect(create_engine(url)).get_table_names())
    assert {
        "users",
        "emergency_contacts",
        "content_versions",
        "content_sources",
        "content_citations",
        "content_chunks",
        "content_cases",
        "content_obligations",
        "embedding_models",
    } <= tables


def test_import_is_idempotent_and_loads_active_pack(tmp_path: Path) -> None:
    repository = DatabaseContentRepository(migrated_database(tmp_path))
    pack = content_pack()
    first = repository.import_pack(pack)
    second = repository.import_pack(pack)
    assert first == second
    loaded = repository.load_active_pack()
    assert loaded is not None
    assert loaded.model_dump(mode="json") == pack.model_dump(mode="json")
    with repository.sessions() as session:
        assert len(session.scalars(select(ContentVersionRecord)).all()) == 1
        assert len(session.scalars(select(ChunkRecord)).all()) > 0


def test_changed_pack_creates_immutable_version_and_reembedding_queue(tmp_path: Path) -> None:
    repository = DatabaseContentRepository(migrated_database(tmp_path))
    original = content_pack()
    repository.import_pack(original)
    changed = original.model_copy(update={"version": original.version + 1, "built_at": "2026-07-24"})
    changed_id = repository.import_pack(changed)
    model_id = repository.register_embedding_model("test", "small", "v1", 1024)
    pending = repository.chunks_requiring_embedding(model_id)
    assert pending
    repository.save_embedding(pending[0]["id"], model_id, [0.0] * 1024)
    remaining_ids = {item["id"] for item in repository.chunks_requiring_embedding(model_id)}
    assert pending[0]["id"] not in remaining_ids
    with repository.sessions() as session:
        versions = session.scalars(select(ContentVersionRecord)).all()
        assert len(versions) == 2
        assert [item.id for item in versions if item.active] == [changed_id]
