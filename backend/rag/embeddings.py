"""A small, dependency-free TF-IDF embedder for offline, provider-agnostic retrieval.

This keeps the MVP runnable with no external API keys. The `Embedder` protocol lets
a real embedding provider (e.g. a hosted model) be swapped in without touching callers.
"""

import re
from collections import Counter
from math import log, sqrt
from typing import Protocol

TOKEN = re.compile(r"[a-z0-9]+")

# Common words carry no retrieval signal and can cause false matches (e.g. "the"
# linking an off-topic query to a document). Dropping them makes cite-or-refuse reliable.
STOPWORDS = frozenset(
    """a an and are as at be by for from has have how i in is it its me my no not of on or
    that the their they this to was what when where which who will with you your can could do
    does did should would may might must shall am been being if then than there here about
    into over under out up down more most some any all one two""".split()
)

Vector = dict[str, float]


def tokenize(text: str) -> list[str]:
    """Lowercase alphanumeric tokenisation, dropping stopwords and single-char tokens.

    Single-char tokens (e.g. the 's' from 's.35(2)') carry no retrieval signal and can
    cause spurious matches, so they are removed.
    """
    return [t for t in TOKEN.findall(text.lower()) if len(t) > 1 and t not in STOPWORDS]


def cosine(a: Vector, b: Vector) -> float:
    """Cosine similarity between two sparse vectors."""
    if not a or not b:
        return 0.0
    common = set(a) & set(b)
    dot = sum(a[t] * b[t] for t in common)
    na = sqrt(sum(v * v for v in a.values()))
    nb = sqrt(sum(v * v for v in b.values()))
    if na == 0.0 or nb == 0.0:
        return 0.0
    return dot / (na * nb)


class Embedder(Protocol):
    def embed(self, text: str) -> Vector: ...


class TfidfEmbedder:
    """TF-IDF embedder fit on a fixed corpus."""

    def __init__(self, corpus: list[str]) -> None:
        self._idf: Vector = self._compute_idf(corpus)

    @staticmethod
    def _compute_idf(corpus: list[str]) -> Vector:
        n_docs = len(corpus)
        df: Counter[str] = Counter()
        for doc in corpus:
            for term in set(tokenize(doc)):
                df[term] += 1
        # smoothed idf so unseen/rare terms stay well-behaved
        return {term: log((n_docs + 1) / (freq + 1)) + 1.0 for term, freq in df.items()}

    def embed(self, text: str) -> Vector:
        """Return an L2-normalisable TF-IDF vector for the text."""
        counts = Counter(tokenize(text))
        if not counts:
            return {}
        max_tf = max(counts.values())
        vec: Vector = {}
        for term, tf in counts.items():
            idf = self._idf.get(term)
            if idf is None:
                continue
            vec[term] = (0.5 + 0.5 * tf / max_tf) * idf
        return vec


if __name__ == "__main__":

    def test_tokenize() -> None:
        assert tokenize("Arrest, s.35(2)!") == ["arrest", "35"]
        print("test_tokenize passed")

    def test_cosine_identity_and_orthogonal() -> None:
        corpus = ["arrest police rights", "tenant landlord rent", "phone privacy search"]
        emb = TfidfEmbedder(corpus)
        v = emb.embed("arrest police rights")
        assert cosine(v, v) > 0.999
        assert cosine(emb.embed("arrest police"), emb.embed("tenant landlord")) < 0.2
        print("test_cosine_identity_and_orthogonal passed")

    def test_relevant_query_ranks_first() -> None:
        docs = [
            "your rights when you are arrested remain silent lawyer",
            "can the police search your phone privacy",
            "how long can the police detain you time limits",
        ]
        emb = TfidfEmbedder(docs)
        q = emb.embed("police searching my phone")
        scores = [cosine(q, emb.embed(d)) for d in docs]
        assert scores.index(max(scores)) == 1
        print("test_relevant_query_ranks_first passed")

    def test_empty_text_returns_empty_vector() -> None:
        emb = TfidfEmbedder(["something here"])
        assert emb.embed("") == {}
        print("test_empty_text_returns_empty_vector passed")

    test_tokenize()
    test_cosine_identity_and_orthogonal()
    test_relevant_query_ranks_first()
    test_empty_text_returns_empty_vector()
    print("\nAll tests passed!")
