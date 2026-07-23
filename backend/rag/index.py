"""Build retrievable documents from verified content and rank them for a query.

Only verified content is indexed here - the trust rule that unverified material never
reaches the AI is enforced upstream (see build_documents in answerer wiring)."""

import sys
from dataclasses import dataclass, field
from pathlib import Path

_ROOT = str(Path(__file__).resolve().parents[2])
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from backend.rag.embeddings import TfidfEmbedder, Vector, cosine, tokenize  # noqa: E402


@dataclass
class Document:
    doc_id: str
    kind: str
    title: str
    topic_id: str
    text: str
    answer_text: str = ""
    citations: list[dict] = field(default_factory=list)


@dataclass
class ScoredDocument:
    document: Document
    score: float


class Retriever:
    """Hybrid retriever: TF-IDF cosine similarity plus a small keyword-overlap bonus."""

    def __init__(self, documents: list[Document], keyword_weight: float = 0.15) -> None:
        self._documents = documents
        self._keyword_weight = keyword_weight
        corpus = [d.text for d in documents] or [""]
        self._embedder = TfidfEmbedder(corpus)
        self._vectors: list[Vector] = [self._embedder.embed(d.text) for d in documents]
        self._token_sets: list[set[str]] = [set(tokenize(d.text)) for d in documents]

    def _keyword_overlap(self, query_tokens: set[str], doc_tokens: set[str]) -> float:
        if not query_tokens:
            return 0.0
        return len(query_tokens & doc_tokens) / len(query_tokens)

    def retrieve(self, query: str, top_k: int = 3) -> list[ScoredDocument]:
        """Return the top_k documents ranked by hybrid score (highest first)."""
        if not self._documents:
            return []
        q_vec = self._embedder.embed(query)
        q_tokens = set(tokenize(query))
        scored: list[ScoredDocument] = []
        for doc, vec, toks in zip(self._documents, self._vectors, self._token_sets, strict=False):
            sim = cosine(q_vec, vec)
            overlap = self._keyword_overlap(q_tokens, toks)
            scored.append(ScoredDocument(doc, sim + self._keyword_weight * overlap))
        scored.sort(key=lambda s: s.score, reverse=True)
        return scored[:top_k]


if __name__ == "__main__":

    def _docs() -> list[Document]:
        return [
            Document(
                "t:arrest", "topic", "Your rights when you are arrested", "rights-when-arrested",
                "arrested police remain silent lawyer informed in writing within 24 hours",
                citations=[{"source_name": "1999 Constitution", "locator": "s.35(2)"}],
            ),
            Document(
                "t:phone", "topic", "Can the police search your phone?", "privacy-and-phone-searches",
                "police search phone privacy correspondence telephone conversations protected",
                citations=[{"source_name": "1999 Constitution", "locator": "s.37"}],
            ),
            Document(
                "t:detain", "topic", "How long can the police hold you?", "detention-and-time-limits",
                "detained brought before court reasonable time one day two days released bail",
                citations=[{"source_name": "1999 Constitution", "locator": "s.35(4)"}],
            ),
        ]

    def test_retrieve_ranks_relevant_first() -> None:
        r = Retriever(_docs())
        top = r.retrieve("can they search my phone", top_k=1)
        assert top[0].document.topic_id == "privacy-and-phone-searches"
        print("test_retrieve_ranks_relevant_first passed")

    def test_retrieve_respects_top_k() -> None:
        r = Retriever(_docs())
        assert len(r.retrieve("police", top_k=2)) == 2
        print("test_retrieve_respects_top_k passed")

    def test_empty_index_returns_empty() -> None:
        assert Retriever([]).retrieve("anything") == []
        print("test_empty_index_returns_empty passed")

    def test_irrelevant_query_scores_low() -> None:
        r = Retriever(_docs())
        top = r.retrieve("football transfer news", top_k=1)
        assert top[0].score < 0.2
        print("test_irrelevant_query_scores_low passed")

    test_retrieve_ranks_relevant_first()
    test_retrieve_respects_top_k()
    test_empty_index_returns_empty()
    test_irrelevant_query_scores_low()
    print("\nAll tests passed!")
