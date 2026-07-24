import json

from backend.rag.answerer import ExtractiveAnswerer, GenerativeAnswerer
from backend.rag.index import Document, Retriever


class FakeResponse:
    def __init__(self, payload: dict, status_code: int = 200) -> None:
        self._payload = payload
        self.status_code = status_code

    def raise_for_status(self) -> None:
        if self.status_code >= 400:
            raise RuntimeError("request failed")

    def json(self) -> dict:
        return self._payload


class FakeClient:
    def __init__(self, answer: dict) -> None:
        self.answer = answer
        self.last_request: dict | None = None

    def post(self, path: str, **kwargs) -> FakeResponse:
        self.last_request = {"path": path, **kwargs}
        return FakeResponse(
            {
                "output": [
                    {
                        "content": [
                            {
                                "type": "output_text",
                                "text": json.dumps(self.answer),
                            }
                        ]
                    }
                ]
            }
        )


def build_answerer(answer: dict) -> tuple[GenerativeAnswerer, FakeClient]:
    document = Document(
        doc_id="topic:phone",
        kind="topic",
        title="Phone privacy",
        topic_id="phone",
        text="police search phone privacy correspondence protected",
        answer_text="Phone correspondence is protected by section 37.",
        citations=[
            {
                "source_name": "1999 Constitution",
                "locator": "s.37",
            }
        ],
    )
    retriever = Retriever([document])
    fallback = ExtractiveAnswerer(retriever)
    client = FakeClient(answer)
    return (
        GenerativeAnswerer(
            retriever,
            fallback,
            api_key="test-key",
            client=client,
        ),
        client,
    )


def test_generated_answer_resolves_only_stored_citations() -> None:
    answerer, client = build_answerer(
        {
            "refused": False,
            "answer": "Your phone correspondence has constitutional protection.",
            "source_ids": ["topic:phone"],
        }
    )

    result = answerer.answer("can police search my phone")

    assert result.refused is False
    assert result.citations[0].locator == "s.37"
    assert client.last_request is not None
    assert client.last_request["path"] == "/v1/responses"
    request_text = client.last_request["json"]["input"]
    assert "OPENAI_API_KEY" not in request_text


def test_unknown_model_source_id_falls_back_to_extractive_answer() -> None:
    answerer, _ = build_answerer(
        {
            "refused": False,
            "answer": "Invented answer.",
            "source_ids": ["made-up-source"],
        }
    )

    result = answerer.answer("can police search my phone")

    assert result.refused is False
    assert result.citations[0].locator == "s.37"
    assert "Phone privacy" in result.answer
    assert "Invented answer" not in result.answer


def test_irrelevant_question_never_reaches_model() -> None:
    answerer, client = build_answerer(
        {
            "refused": False,
            "answer": "The weather is sunny.",
            "source_ids": ["topic:phone"],
        }
    )

    result = answerer.answer("what is the weather tomorrow")

    assert result.refused is True
    assert result.citations == []
    assert client.last_request is None
