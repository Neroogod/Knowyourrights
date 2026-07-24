"""Versioned SQL content persistence for PostgreSQL production and SQLite tests."""

from __future__ import annotations

import hashlib
import json
import os
import re
import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    create_engine,
    func,
    select,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker
from sqlalchemy.types import JSON, TypeDecorator, UserDefinedType

from backend.schemas import ContentPack


class Vector(UserDefinedType):
    """Minimal pgvector type so migrations do not require a runtime pgvector package."""

    cache_ok = True

    def __init__(self, dimensions: int = 1536) -> None:
        self.dimensions = dimensions

    def get_col_spec(self, **_: Any) -> str:
        return f"vector({self.dimensions})"


class PortableVector(TypeDecorator):
    """pgvector on PostgreSQL and JSON elsewhere for migration/repository tests."""

    impl = JSON
    cache_ok = True

    def __init__(self, dimensions: int = 1536) -> None:
        super().__init__()
        self.dimensions = dimensions

    def load_dialect_impl(self, dialect: Any) -> Any:
        if dialect.name == "postgresql":
            return dialect.type_descriptor(Vector(self.dimensions))
        return dialect.type_descriptor(JSON())


class PortableJSON(TypeDecorator):
    impl = JSON
    cache_ok = True

    def load_dialect_impl(self, dialect: Any) -> Any:
        if dialect.name == "postgresql":
            return dialect.type_descriptor(JSONB())
        return dialect.type_descriptor(JSON())


class ContentBase(DeclarativeBase):
    pass


def new_id() -> str:
    return str(uuid.uuid4())


class ContentVersionRecord(ContentBase):
    __tablename__ = "content_versions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    pack_version: Mapped[int] = mapped_column(Integer, nullable=False)
    checksum: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    built_at: Mapped[str] = mapped_column(String(40), nullable=False)
    imported_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, index=True)
    importer_version: Mapped[str] = mapped_column(String(40), nullable=False)
    __table_args__ = (UniqueConstraint("pack_version", "checksum", name="uq_content_version_pack"),)


class CategoryRecord(ContentBase):
    __tablename__ = "content_categories"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    content_id: Mapped[str] = mapped_column(String(160), nullable=False)
    version_id: Mapped[str] = mapped_column(ForeignKey("content_versions.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    parent_content_id: Mapped[str | None] = mapped_column(String(160))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    __table_args__ = (UniqueConstraint("content_id", "version_id", name="uq_category_version"),)


class SourceRecord(ContentBase):
    __tablename__ = "content_sources"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    content_id: Mapped[str] = mapped_column(String(160), nullable=False)
    version_id: Mapped[str] = mapped_column(ForeignKey("content_versions.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    source_type: Mapped[str] = mapped_column(String(40), default="legal_source")
    jurisdiction: Mapped[str] = mapped_column(String(80), default="NG-Federal")
    url: Mapped[str | None] = mapped_column(Text)
    license: Mapped[str] = mapped_column(String(40), default="public")
    is_authoritative: Mapped[bool] = mapped_column(Boolean, default=True)
    metadata_json: Mapped[dict] = mapped_column(PortableJSON, default=dict)
    __table_args__ = (UniqueConstraint("content_id", "version_id", name="uq_source_version"),)


class VersionedPayloadMixin:
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    content_id: Mapped[str] = mapped_column(String(160), nullable=False)
    version_id: Mapped[str] = mapped_column(ForeignKey("content_versions.id", ondelete="CASCADE"))
    status: Mapped[str] = mapped_column(String(24), nullable=False, index=True)
    jurisdiction: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(400), nullable=False)
    body_text: Mapped[str] = mapped_column(Text, nullable=False)
    payload: Mapped[dict] = mapped_column(PortableJSON, nullable=False)
    reviewed_by: Mapped[str | None] = mapped_column(String(180))
    reviewed_at: Mapped[str | None] = mapped_column(String(40))


class TopicRecord(VersionedPayloadMixin, ContentBase):
    __tablename__ = "content_topics"
    category_content_id: Mapped[str] = mapped_column(String(160), index=True)
    __table_args__ = (UniqueConstraint("content_id", "version_id", name="uq_topic_version"),)


class ScenarioRecord(VersionedPayloadMixin, ContentBase):
    __tablename__ = "content_scenarios"
    __table_args__ = (UniqueConstraint("content_id", "version_id", name="uq_scenario_version"),)


class ObligationRecord(VersionedPayloadMixin, ContentBase):
    __tablename__ = "content_obligations"
    category_content_id: Mapped[str] = mapped_column(String(160), index=True)
    review_due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    __table_args__ = (UniqueConstraint("content_id", "version_id", name="uq_obligation_version"),)


class ChecklistRecord(VersionedPayloadMixin, ContentBase):
    __tablename__ = "content_checklists"
    __table_args__ = (UniqueConstraint("content_id", "version_id", name="uq_checklist_version"),)


class CaseRecord(VersionedPayloadMixin, ContentBase):
    __tablename__ = "content_cases"
    court: Mapped[str] = mapped_column(String(180), nullable=False)
    year: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    area_of_law: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    __table_args__ = (UniqueConstraint("content_id", "version_id", name="uq_case_version"),)


class DirectoryRecord(ContentBase):
    __tablename__ = "content_directory_entries"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    content_id: Mapped[str] = mapped_column(String(160), nullable=False)
    version_id: Mapped[str] = mapped_column(ForeignKey("content_versions.id", ondelete="CASCADE"))
    name: Mapped[str] = mapped_column(String(300), nullable=False)
    entry_type: Mapped[str] = mapped_column(String(60), nullable=False, index=True)
    payload: Mapped[dict] = mapped_column(PortableJSON, nullable=False)
    __table_args__ = (UniqueConstraint("content_id", "version_id", name="uq_directory_version"),)


class CitationRecord(ContentBase):
    __tablename__ = "content_citations"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    version_id: Mapped[str] = mapped_column(ForeignKey("content_versions.id", ondelete="CASCADE"))
    target_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    target_content_id: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    source_content_id: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    locator: Mapped[str] = mapped_column(String(240), nullable=False)
    quote: Mapped[str | None] = mapped_column(Text)
    url: Mapped[str | None] = mapped_column(Text)


class EmbeddingModelRecord(ContentBase):
    __tablename__ = "embedding_models"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    provider: Mapped[str] = mapped_column(String(80), nullable=False)
    model: Mapped[str] = mapped_column(String(180), nullable=False)
    model_version: Mapped[str] = mapped_column(String(80), nullable=False)
    dimensions: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    __table_args__ = (
        UniqueConstraint("provider", "model", "model_version", name="uq_embedding_model_version"),
    )


class ChunkRecord(ContentBase):
    __tablename__ = "content_chunks"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    content_id: Mapped[str] = mapped_column(String(200), nullable=False)
    version_id: Mapped[str] = mapped_column(ForeignKey("content_versions.id", ondelete="CASCADE"))
    parent_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    parent_content_id: Mapped[str] = mapped_column(String(160), nullable=False, index=True)
    source_content_id: Mapped[str | None] = mapped_column(String(160), index=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    token_count: Mapped[int] = mapped_column(Integer, nullable=False)
    ordinal: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False, index=True)
    jurisdiction: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    embedding_model_id: Mapped[str | None] = mapped_column(ForeignKey("embedding_models.id"))
    embedding: Mapped[list[float] | None] = mapped_column(PortableVector(1024))
    embedded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    __table_args__ = (
        UniqueConstraint("content_id", "version_id", name="uq_chunk_version"),
        Index("ix_chunks_filter", "status", "jurisdiction", "parent_type"),
    )


CONTENT_TABLES = (
    CategoryRecord,
    SourceRecord,
    TopicRecord,
    ScenarioRecord,
    ObligationRecord,
    ChecklistRecord,
    CaseRecord,
    DirectoryRecord,
    CitationRecord,
    ChunkRecord,
)


class DatabaseContentRepository:
    """Imports immutable packs and reconstructs the active validated pack."""

    IMPORTER_VERSION = "1"

    def __init__(self, database_url: str) -> None:
        connect_args = {"check_same_thread": False} if database_url.startswith("sqlite") else {}
        self.engine = create_engine(database_url, connect_args=connect_args)
        self.sessions = sessionmaker(self.engine, expire_on_commit=False)

    @staticmethod
    def checksum(pack: ContentPack) -> str:
        canonical = json.dumps(pack.model_dump(mode="json"), sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(canonical.encode()).hexdigest()

    def import_pack(self, pack: ContentPack, activate: bool = True) -> str:
        checksum = self.checksum(pack)
        with self.sessions.begin() as session:
            existing = session.scalar(
                select(ContentVersionRecord).where(ContentVersionRecord.checksum == checksum)
            )
            if existing:
                if activate and not existing.active:
                    session.query(ContentVersionRecord).update({"active": False})
                    existing.active = True
                return existing.id
            if activate:
                session.query(ContentVersionRecord).update({"active": False})
            version = ContentVersionRecord(
                pack_version=pack.version,
                checksum=checksum,
                built_at=pack.built_at,
                imported_at=datetime.now(UTC),
                active=activate,
                importer_version=self.IMPORTER_VERSION,
            )
            session.add(version)
            session.flush()
            self._insert_pack(session, version.id, pack)
            return version.id

    def _insert_pack(self, session: Any, version_id: str, pack: ContentPack) -> None:
        categories: dict[str, str] = {}
        source_names: set[str] = set()
        for item in [*pack.topics, *pack.obligations]:
            categories[item.category] = item.category.replace("-", " ").title()
        for item in [*pack.topics, *pack.scenarios, *pack.obligations, *pack.company_checklists, *pack.cases]:
            source_names.update(c.source_name for c in item.citations)
        session.add_all(
            CategoryRecord(content_id=key, version_id=version_id, name=name)
            for key, name in categories.items()
        )
        session.add_all(
            SourceRecord(
                content_id=self._source_id(name),
                version_id=version_id,
                name=name,
                source_type=self._source_type(name),
                is_authoritative=self._is_authoritative(name),
            )
            for name in sorted(source_names)
        )
        for topic in pack.topics:
            self._add_payload(session, TopicRecord, topic, version_id, category_content_id=topic.category)
            self._add_citations(session, version_id, "topic", topic.id, topic.citations)
            self._add_chunk(session, version_id, "topic", topic)
        for scenario in pack.scenarios:
            self._add_payload(session, ScenarioRecord, scenario, version_id)
            self._add_citations(session, version_id, "scenario", scenario.id, scenario.citations)
        for obligation in pack.obligations:
            self._add_payload(
                session,
                ObligationRecord,
                obligation,
                version_id,
                category_content_id=obligation.category,
                review_due_at=None,
            )
            self._add_citations(session, version_id, "obligation", obligation.id, obligation.citations)
            self._add_chunk(session, version_id, "obligation", obligation)
        for checklist in pack.company_checklists:
            self._add_payload(session, ChecklistRecord, checklist, version_id)
            self._add_citations(session, version_id, "checklist", checklist.id, checklist.citations)
        for case in pack.cases:
            self._add_payload(
                session,
                CaseRecord,
                case,
                version_id,
                court=case.court,
                year=case.year,
                area_of_law=case.area_of_law,
            )
            self._add_citations(session, version_id, "case", case.id, case.citations)
            self._add_chunk(session, version_id, "case", case)
        session.add_all(
            DirectoryRecord(
                content_id=item.id,
                version_id=version_id,
                name=item.name,
                entry_type=item.entry_type,
                payload=item.model_dump(mode="json"),
            )
            for item in pack.directory
        )

    def _add_payload(self, session: Any, model: type, item: Any, version_id: str, **extra: Any) -> None:
        payload = item.model_dump(mode="json")
        body = payload.get("body_plain") or payload.get("summary") or payload.get("description", "")
        session.add(
            model(
                content_id=item.id,
                version_id=version_id,
                status=item.status.value,
                jurisdiction=item.jurisdiction,
                title=payload.get("title") or payload.get("trigger") or payload.get("name"),
                body_text=body,
                payload=payload,
                reviewed_by=payload.get("reviewed_by"),
                reviewed_at=payload.get("reviewed_at"),
                **extra,
            )
        )

    def _add_citations(
        self, session: Any, version_id: str, target_type: str, target_id: str, citations: list
    ) -> None:
        session.add_all(
            CitationRecord(
                version_id=version_id,
                target_type=target_type,
                target_content_id=target_id,
                source_content_id=self._source_id(citation.source_name),
                locator=citation.locator,
                quote=citation.quote,
                url=citation.url,
            )
            for citation in citations
        )

    def _add_chunk(self, session: Any, version_id: str, parent_type: str, item: Any) -> None:
        payload = item.model_dump(mode="json")
        text = " ".join(
            str(value)
            for key, value in payload.items()
            if key in {"title", "name", "summary", "body_plain", "facts", "holding", "ratio", "requirements"}
        )
        source = item.citations[0].source_name if item.citations else None
        session.add(
            ChunkRecord(
                content_id=f"{parent_type}:{item.id}:0",
                version_id=version_id,
                parent_type=parent_type,
                parent_content_id=item.id,
                source_content_id=self._source_id(source) if source else None,
                text=text,
                token_count=len(text.split()),
                ordinal=0,
                status=item.status.value,
                jurisdiction=item.jurisdiction,
            )
        )

    def load_active_pack(self) -> ContentPack | None:
        with self.sessions() as session:
            version = session.scalar(
                select(ContentVersionRecord)
                .where(ContentVersionRecord.active.is_(True))
                .order_by(ContentVersionRecord.imported_at.desc())
            )
            if not version:
                return None

            def payloads(model: type) -> list[dict]:
                return list(session.scalars(select(model.payload).where(model.version_id == version.id)))

            return ContentPack.model_validate(
                {
                    "version": version.pack_version,
                    "built_at": version.built_at,
                    "topics": payloads(TopicRecord),
                    "scenarios": payloads(ScenarioRecord),
                    "directory": payloads(DirectoryRecord),
                    "obligations": payloads(ObligationRecord),
                    "company_checklists": payloads(ChecklistRecord),
                    "cases": payloads(CaseRecord),
                }
            )

    def register_embedding_model(self, provider: str, model: str, model_version: str, dimensions: int) -> str:
        with self.sessions.begin() as session:
            record = session.scalar(
                select(EmbeddingModelRecord).where(
                    EmbeddingModelRecord.provider == provider,
                    EmbeddingModelRecord.model == model,
                    EmbeddingModelRecord.model_version == model_version,
                )
            )
            if record:
                if not record.active:
                    session.query(EmbeddingModelRecord).update({"active": False})
                    record.active = True
                return record.id
            session.query(EmbeddingModelRecord).update({"active": False})
            record = EmbeddingModelRecord(
                provider=provider,
                model=model,
                model_version=model_version,
                dimensions=dimensions,
                created_at=datetime.now(UTC),
                active=True,
            )
            session.add(record)
            session.flush()
            return record.id

    def chunks_requiring_embedding(self, model_id: str, limit: int = 100) -> list[dict]:
        with self.sessions() as session:
            active = session.scalar(select(ContentVersionRecord).where(ContentVersionRecord.active.is_(True)))
            if not active:
                return []
            rows = session.scalars(
                select(ChunkRecord)
                .where(
                    ChunkRecord.version_id == active.id,
                    ChunkRecord.status == "verified",
                    (ChunkRecord.embedding_model_id != model_id) | ChunkRecord.embedding_model_id.is_(None),
                )
                .order_by(ChunkRecord.parent_type, ChunkRecord.parent_content_id, ChunkRecord.ordinal)
                .limit(limit)
            )
            return [{"id": row.id, "text": row.text} for row in rows]

    def save_embedding(self, chunk_id: str, model_id: str, embedding: list[float]) -> None:
        with self.sessions.begin() as session:
            chunk = session.get(ChunkRecord, chunk_id)
            if not chunk:
                raise ValueError("chunk not found")
            chunk.embedding_model_id = model_id
            chunk.embedding = embedding
            chunk.embedded_at = datetime.now(UTC)

    def embedding_coverage(self, model_id: str) -> tuple[int, int]:
        """Return verified active chunks and those embedded with this model."""
        with self.sessions() as session:
            active = session.scalar(
                select(ContentVersionRecord).where(ContentVersionRecord.active.is_(True))
            )
            if active is None:
                return 0, 0
            filters = (
                ChunkRecord.version_id == active.id,
                ChunkRecord.status == "verified",
            )
            total = int(
                session.scalar(select(func.count()).where(*filters)) or 0
            )
            embedded = int(
                session.scalar(
                    select(func.count()).where(
                        *filters,
                        ChunkRecord.embedding_model_id == model_id,
                        ChunkRecord.embedding.is_not(None),
                    )
                )
                or 0
            )
            return total, embedded

    def search_chunks(
        self,
        embedding: list[float],
        *,
        query_text: str,
        parent_type: str,
        jurisdiction: str = "NG-Federal",
        embedding_model_id: str | None = None,
        top_k: int = 5,
    ) -> list[dict]:
        if self.engine.dialect.name != "postgresql":
            raise RuntimeError("vector retrieval requires PostgreSQL with pgvector")
        parent_tables = {
            "topic": "content_topics",
            "obligation": "content_obligations",
            "case": "content_cases",
        }
        parent_table = parent_tables.get(parent_type)
        if not parent_table:
            raise ValueError("unsupported vector-retrieval corpus")
        vector = "[" + ",".join(f"{value:.10g}" for value in embedding) + "]"
        lexical_terms = re.findall(r"[A-Za-z0-9]{2,}", query_text)[:12]
        lexical_query = " OR ".join(lexical_terms) or query_text
        statement = text(
            f"""
            WITH eligible AS (
                SELECT c.*, p.payload,
                       1 - (c.embedding <=> CAST(:embedding AS vector)) AS vector_score,
                       ts_rank_cd(
                           to_tsvector('english', c.text),
                           websearch_to_tsquery('english', :lexical_query)
                       ) AS text_score
                FROM content_chunks c
                JOIN content_versions v ON v.id = c.version_id AND v.active = true
                LEFT JOIN {parent_table} p
                  ON p.content_id = c.parent_content_id AND p.version_id = c.version_id
                WHERE c.status = 'verified'
                  AND c.parent_type = :parent_type
                  AND c.jurisdiction IN (:jurisdiction, 'NG-Federal')
                  AND c.embedding IS NOT NULL
                  AND (CAST(:embedding_model_id AS varchar) IS NULL
                       OR c.embedding_model_id = :embedding_model_id)
            ),
            vector_ranked AS (
                SELECT id, row_number() OVER (ORDER BY vector_score DESC) AS rank
                FROM eligible ORDER BY vector_score DESC LIMIT 30
            ),
            text_ranked AS (
                SELECT id, row_number() OVER (ORDER BY text_score DESC) AS rank
                FROM eligible WHERE text_score > 0 ORDER BY text_score DESC LIMIT 30
            )
            SELECT e.content_id, e.parent_type, e.parent_content_id, e.text, e.payload,
                   e.vector_score, e.text_score,
                   COALESCE(1.0 / (60 + vr.rank), 0) +
                   COALESCE(1.0 / (60 + tr.rank), 0) AS fused_score
            FROM eligible e
            LEFT JOIN vector_ranked vr ON vr.id = e.id
            LEFT JOIN text_ranked tr ON tr.id = e.id
            WHERE vr.id IS NOT NULL OR tr.id IS NOT NULL
            ORDER BY fused_score DESC, vector_score DESC
            LIMIT :top_k
            """
        )
        with self.engine.connect() as connection:
            rows = connection.execute(
                statement,
                {
                    "embedding": vector,
                    "lexical_query": lexical_query,
                    "parent_type": parent_type,
                    "jurisdiction": jurisdiction,
                    "embedding_model_id": embedding_model_id,
                    "top_k": max(top_k * 4, 12),
                },
            ).mappings()
            return [dict(row) for row in rows]

    @staticmethod
    def _source_id(name: str) -> str:
        return hashlib.sha256(name.strip().lower().encode()).hexdigest()[:32]

    @staticmethod
    def _source_type(name: str) -> str:
        lowered = name.lower()
        if "constitution" in lowered:
            return "constitution"
        if " v " in lowered or "nwl" in lowered:
            return "case"
        return "act"

    @staticmethod
    def _is_authoritative(name: str) -> bool:
        lowered = name.lower()
        return any(word in lowered for word in ("constitution", " act", " v "))


def content_repository_from_environment() -> DatabaseContentRepository | None:
    if os.getenv("KYR_CONTENT_BACKEND", "json") != "database":
        return None
    url = os.getenv("CONTENT_DATABASE_URL") or os.getenv("DATABASE_URL")
    if not url:
        raise RuntimeError("CONTENT_DATABASE_URL or DATABASE_URL is required for database content")
    return DatabaseContentRepository(url)
