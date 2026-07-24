"""Production OpenAI embeddings plus PostgreSQL/pgvector retrieval."""

from __future__ import annotations

import json
import os
import urllib.request
from dataclasses import dataclass
from typing import Protocol

from backend.content_db import DatabaseContentRepository
from backend.rag.index import Document, ScoredDocument


@dataclass(frozen=True)
class EmbeddingConfiguration:
    provider: str = "local"
    model: str = "BAAI/bge-m3"
    model_version: str = "main"
    dimensions: int = 1024

    @classmethod
    def from_environment(cls) -> EmbeddingConfiguration:
        return cls(
            provider=os.getenv("KYR_EMBEDDING_PROVIDER", cls.provider),
            model=os.getenv("KYR_EMBEDDING_MODEL", cls.model),
            model_version=os.getenv("KYR_EMBEDDING_MODEL_VERSION", cls.model_version),
            dimensions=int(os.getenv("KYR_EMBEDDING_DIMENSIONS", str(cls.dimensions))),
        )


class EmbeddingProvider(Protocol):
    configuration: EmbeddingConfiguration

    def embed(self, text: str) -> list[float]: ...


class LocalSentenceTransformerProvider:
    """Runs BGE-M3 locally; model loading is lazy so normal startup stays fast."""

    def __init__(self, configuration: EmbeddingConfiguration) -> None:
        self.configuration = configuration
        self._model = None

    def _load_model(self):
        if self._model is None:
            from sentence_transformers import SentenceTransformer

            self._model = SentenceTransformer(self.configuration.model)
        return self._model

    def embed(self, text: str) -> list[float]:
        vector = self._load_model().encode(
            text,
            normalize_embeddings=True,
            show_progress_bar=False,
        )
        values = vector.tolist()
        if len(values) != self.configuration.dimensions:
            raise RuntimeError(
                f"embedding dimension mismatch: expected {self.configuration.dimensions}, "
                f"received {len(values)}"
            )
        return [float(value) for value in values]


class OpenAIEmbeddingProvider:
    def __init__(self, api_key: str, configuration: EmbeddingConfiguration) -> None:
        self.api_key = api_key
        self.configuration = configuration

    @classmethod
    def from_environment(cls) -> OpenAIEmbeddingProvider | None:
        key = os.getenv("OPENAI_API_KEY")
        if not key:
            return None
        configuration = EmbeddingConfiguration(
            provider="openai",
            model=os.getenv("KYR_EMBEDDING_MODEL", "text-embedding-3-small"),
            model_version=os.getenv("KYR_EMBEDDING_MODEL_VERSION", "2024-01"),
            dimensions=int(os.getenv("KYR_EMBEDDING_DIMENSIONS", "1024")),
        )
        return cls(key, configuration)

    def embed(self, text: str) -> list[float]:
        request = urllib.request.Request(
            "https://api.openai.com/v1/embeddings",
            data=json.dumps(
                {
                    "model": self.configuration.model,
                    "input": text,
                    "dimensions": self.configuration.dimensions,
                    "encoding_format": "float",
                }
            ).encode(),
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read())
        return [float(value) for value in payload["data"][0]["embedding"]]


class PgVectorRetriever:
    """Retriever-compatible adapter used by the existing cite-or-refuse answerer."""

    def __init__(
        self,
        repository: DatabaseContentRepository,
        embedder: EmbeddingProvider,
        parent_type: str,
        jurisdiction: str = "NG-Federal",
        min_similarity: float = 0.2,
    ) -> None:
        self.repository = repository
        self.embedder = embedder
        self.parent_type = parent_type
        self.jurisdiction = jurisdiction
        self.min_similarity = min_similarity
        config = embedder.configuration
        self.model_id = repository.register_embedding_model(
            config.provider,
            config.model,
            config.model_version,
            config.dimensions,
        )

    def retrieve(self, query: str, top_k: int = 3) -> list[ScoredDocument]:
        rows = self.repository.search_chunks(
            self.embedder.embed(query),
            query_text=query,
            parent_type=self.parent_type,
            jurisdiction=self.jurisdiction,
            embedding_model_id=self.model_id,
            top_k=max(top_k, 10),
        )
        query_terms = {term for term in query.lower().split() if len(term) > 2}
        rows.sort(
            key=lambda row: (
                float(row.get("fused_score") or 0)
                + 0.002 * len(query_terms & set(str(row["text"]).lower().split())),
                float(row.get("vector_score") or 0),
            ),
            reverse=True,
        )
        results: list[ScoredDocument] = []
        for row in rows:
            confidence = max(
                float(row.get("vector_score") or 0),
                min(float(row.get("text_score") or 0), 1.0),
            )
            if confidence < self.min_similarity:
                continue
            payload = row.get("payload") or {}
            citations = payload.get("citations") or []
            document = Document(
                doc_id=row["content_id"],
                kind=self.parent_type,
                title=payload.get("title") or payload.get("name") or "",
                topic_id=row["parent_content_id"],
                text=row["text"],
                answer_text=payload.get("body_plain")
                or payload.get("summary")
                or payload.get("ratio")
                or row["text"],
                citations=citations,
                jurisdiction=self.jurisdiction,
            )
            results.append(ScoredDocument(document=document, score=confidence))
        return results[:top_k]


def reembed_active_content(
    repository: DatabaseContentRepository,
    provider: EmbeddingProvider,
    batch_size: int = 100,
) -> int:
    config = provider.configuration
    model_id = repository.register_embedding_model(
        config.provider, config.model, config.model_version, config.dimensions
    )
    count = 0
    while chunks := repository.chunks_requiring_embedding(model_id, batch_size):
        for chunk in chunks:
            repository.save_embedding(chunk["id"], model_id, provider.embed(chunk["text"]))
            count += 1
    return count


def embedding_provider_from_environment() -> EmbeddingProvider | None:
    configuration = EmbeddingConfiguration.from_environment()
    if configuration.provider == "local":
        try:
            import sentence_transformers  # noqa: F401
        except ImportError:
            return None
        return LocalSentenceTransformerProvider(configuration)
    if configuration.provider == "openai":
        return OpenAIEmbeddingProvider.from_environment()
    raise RuntimeError(f"unsupported embedding provider: {configuration.provider}")
