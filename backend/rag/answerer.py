"""Grounded question answering with a hard cite-or-refuse guarantee.

The default `ExtractiveAnswerer` never generates free-form legal text: it returns
wording drawn from verified content and always attaches the source citations. If
retrieval is not confident enough, it refuses. This makes hallucinated legal advice
structurally impossible in the MVP, while the `Answerer` protocol leaves room to plug
in a generative, citation-checked model later.
"""

import sys
from pathlib import Path
from typing import Protocol

_ROOT = str(Path(__file__).resolve().parents[2])
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from backend.rag.index import Document, Retriever  # noqa: E402
from backend.schemas import AnswerCitation, AskResponse, Topic  # noqa: E402

DISCLAIMER = (
    "This is legal information, not legal advice. For advice on your specific "
    "situation, speak to a qualified lawyer."
)
REFUSAL = (
    "I could not find this in the verified Nigerian rights information I have. "
    "I would rather say I don't know than risk giving you wrong legal information. "
    "Please consult a lawyer or the Legal Aid Council - see the Directory."
)
MIN_SCORE = 0.12


def build_documents(topics: list[Topic]) -> list[Document]:
    """Turn verified topics into retrievable documents. Unverified topics are excluded."""
    documents: list[Document] = []
    for topic in topics:
        if topic.status.value != "verified":
            continue
        search_text = " ".join(
            [topic.title, topic.summary, topic.body_plain, *topic.rights, *topic.do_list]
        )
        answer_text = topic.summary
        if topic.rights:
            answer_text += "\n\nKey points:\n" + "\n".join(f"- {r}" for r in topic.rights)
        documents.append(
            Document(
                doc_id=f"topic:{topic.id}",
                kind="topic",
                title=topic.title,
                topic_id=topic.id,
                text=search_text,
                answer_text=answer_text,
                citations=[c.model_dump() for c in topic.citations],
            )
        )
    return documents


class Answerer(Protocol):
    def answer(self, question: str) -> AskResponse: ...


class ExtractiveAnswerer:
    """Answer strictly from the top verified document, or refuse."""

    def __init__(self, retriever: Retriever, min_score: float = MIN_SCORE) -> None:
        self._retriever = retriever
        self._min_score = min_score

    def answer(self, question: str) -> AskResponse:
        results = self._retriever.retrieve(question, top_k=3)
        if not results or results[0].score < self._min_score:
            return AskResponse(
                refused=True,
                answer=REFUSAL,
                citations=[],
                related_topic_ids=[],
                disclaimer=DISCLAIMER,
            )

        best = results[0].document
        citations = [AnswerCitation(**c) for c in best.citations]
        # Trust guarantee: a non-refusal answer must carry at least one citation.
        if not citations:
            return AskResponse(
                refused=True,
                answer=REFUSAL,
                citations=[],
                related_topic_ids=[],
                disclaimer=DISCLAIMER,
            )

        related = [
            r.document.topic_id
            for r in results
            if r.score >= self._min_score and r.document.topic_id != best.topic_id
        ]
        answer = f"{best.title}\n\n{best.answer_text}"
        return AskResponse(
            refused=False,
            answer=answer,
            citations=citations,
            related_topic_ids=related,
            disclaimer=DISCLAIMER,
        )


if __name__ == "__main__":

    def _topics() -> list[Topic]:
        from backend.schemas import Citation, Status

        return [
            Topic(
                id="rights-when-arrested",
                title="Your rights when you are arrested",
                category="arrest-and-police",
                jurisdiction="NG-Federal",
                summary="Stay silent until you speak to a lawyer; you must be told why within 24 hours.",
                body_plain="arrested police remain silent lawyer informed in writing within 24 hours",
                rights=["You may remain silent until you consult a lawyer (s.35(2))."],
                status=Status.verified,
                reviewed_by="L",
                citations=[Citation(source_name="1999 Constitution", locator="s.35(2)")],
            ),
            Topic(
                id="privacy-and-phone-searches",
                title="Can the police search your phone?",
                category="privacy",
                jurisdiction="NG-Federal",
                summary="Your phone and correspondence are private and protected.",
                body_plain="police search phone privacy correspondence telephone conversations protected",
                status=Status.verified,
                reviewed_by="L",
                citations=[Citation(source_name="1999 Constitution", locator="s.37")],
            ),
            Topic(
                id="draft-topic",
                title="Draft, not verified",
                category="x",
                jurisdiction="NG",
                summary="should never be indexed",
                body_plain="secret unverified content about phones",
            ),
        ]

    def _answerer() -> "ExtractiveAnswerer":
        docs = build_documents(_topics())
        return ExtractiveAnswerer(Retriever(docs))

    def test_build_documents_excludes_unverified() -> None:
        docs = build_documents(_topics())
        assert all(d.topic_id != "draft-topic" for d in docs)
        assert len(docs) == 2
        print("test_build_documents_excludes_unverified passed")

    def test_relevant_question_answered_with_citation() -> None:
        resp = _answerer().answer("can the police search my phone")
        assert resp.refused is False
        assert resp.citations and resp.citations[0].locator == "s.37"
        print("test_relevant_question_answered_with_citation passed")

    def test_offtopic_question_refuses() -> None:
        resp = _answerer().answer("what is the price of bitcoin today")
        assert resp.refused is True
        assert resp.citations == []
        print("test_offtopic_question_refuses passed")

    def test_answer_always_has_disclaimer() -> None:
        for q in ("arrested rights", "random gibberish xyz"):
            assert _answerer().answer(q).disclaimer
        print("test_answer_always_has_disclaimer passed")

    def test_no_answer_without_citation() -> None:
        # An answer that is not refused must have at least one citation.
        resp = _answerer().answer("I was arrested by police")
        if not resp.refused:
            assert len(resp.citations) >= 1
        print("test_no_answer_without_citation passed")

    test_build_documents_excludes_unverified()
    test_relevant_question_answered_with_citation()
    test_offtopic_question_refuses()
    test_answer_always_has_disclaimer()
    test_no_answer_without_citation()
    print("\nAll tests passed!")
