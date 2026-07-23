"""In-memory content store: loads the content pack and serves topics, scenarios,
the directory, search, and the grounded Q&A answerer."""

import json
import sys
from pathlib import Path

_ROOT = str(Path(__file__).resolve().parents[1])
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from backend.rag.answerer import (  # noqa: E402
    COMPANY_REFUSAL,
    ExtractiveAnswerer,
    build_company_documents,
    build_documents,
)
from backend.rag.index import Retriever  # noqa: E402
from backend.schemas import (  # noqa: E402
    AskResponse,
    CompanyChecklist,
    ContentPack,
    DirectoryEntry,
    Obligation,
    Scenario,
    Topic,
)

DEFAULT_PACK_PATH = Path(__file__).resolve().parents[1] / "data" / "content_pack.json"


class ContentStore:
    """Serves validated content and answers questions over verified topics only."""

    def __init__(self, pack: ContentPack) -> None:
        self._pack = pack
        self._topics: dict[str, Topic] = {t.id: t for t in pack.topics}
        self._scenarios: dict[str, Scenario] = {s.id: s for s in pack.scenarios}
        self._directory: list[DirectoryEntry] = list(pack.directory)
        self._obligations: dict[str, Obligation] = {item.id: item for item in pack.obligations}
        self._company_checklists: dict[str, CompanyChecklist] = {
            item.id: item for item in pack.company_checklists
        }

        documents = build_documents(pack.topics)
        self._retriever = Retriever(documents)
        self._answerer = ExtractiveAnswerer(self._retriever)
        company_documents = build_company_documents(pack.obligations)
        self._company_answerer = ExtractiveAnswerer(
            Retriever(company_documents),
            refusal=COMPANY_REFUSAL,
        )

    @classmethod
    def from_file(cls, path: Path = DEFAULT_PACK_PATH) -> "ContentStore":
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls(ContentPack.model_validate(data))

    @property
    def version(self) -> int:
        return self._pack.version

    def list_topics(self, category: str | None = None) -> list[Topic]:
        topics = list(self._topics.values())
        if category:
            topics = [t for t in topics if t.category == category]
        return topics

    def get_topic(self, topic_id: str) -> Topic | None:
        return self._topics.get(topic_id)

    def list_scenarios(self) -> list[Scenario]:
        return list(self._scenarios.values())

    def get_scenario(self, scenario_id: str) -> Scenario | None:
        return self._scenarios.get(scenario_id)

    def list_directory(self) -> list[DirectoryEntry]:
        return list(self._directory)

    def list_obligations(self) -> list[Obligation]:
        return list(self._obligations.values())

    def get_obligation(self, obligation_id: str) -> Obligation | None:
        return self._obligations.get(obligation_id)

    def list_company_checklists(self) -> list[CompanyChecklist]:
        return list(self._company_checklists.values())

    def search_topics(self, query: str, top_k: int = 5) -> list[Topic]:
        results = self._retriever.retrieve(query, top_k=top_k)
        topics: list[Topic] = []
        for r in results:
            if r.score <= 0.0:
                continue
            topic = self._topics.get(r.document.topic_id)
            if topic:
                topics.append(topic)
        return topics

    def ask(self, question: str) -> AskResponse:
        return self._answerer.answer(question)

    def ask_company(self, question: str) -> AskResponse:
        return self._company_answerer.answer(question)


if __name__ == "__main__":
    from backend.schemas import Citation, ScenarioStep, Status
    from backend.schemas import DirectoryEntry as DE

    def _pack() -> ContentPack:
        return ContentPack(
            version=1,
            built_at="2026-07-23",
            topics=[
                Topic(
                    id="rights-when-arrested",
                    title="Your rights when you are arrested",
                    category="arrest-and-police",
                    jurisdiction="NG-Federal",
                    summary="Stay silent until you speak to a lawyer.",
                    body_plain="arrested police remain silent lawyer within 24 hours",
                    status=Status.verified,
                    reviewed_by="L",
                    citations=[Citation(source_name="1999 Constitution", locator="s.35(2)")],
                ),
                Topic(
                    id="privacy-and-phone-searches",
                    title="Can the police search your phone?",
                    category="privacy",
                    jurisdiction="NG-Federal",
                    summary="Your phone is private and protected.",
                    body_plain="police search phone privacy telephone conversations protected",
                    status=Status.verified,
                    reviewed_by="L",
                    citations=[Citation(source_name="1999 Constitution", locator="s.37")],
                ),
            ],
            scenarios=[
                Scenario(
                    id="being-arrested",
                    trigger="I am being arrested",
                    description="Steps",
                    jurisdiction="NG-Federal",
                    steps=[ScenarioStep(text="Stay calm")],
                )
            ],
            directory=[DE(id="d1", name="Legal Aid Council", entry_type="legal_aid")],
        )

    def test_list_and_get() -> None:
        s = ContentStore(_pack())
        assert len(s.list_topics()) == 2
        assert len(s.list_topics(category="privacy")) == 1
        assert s.get_topic("rights-when-arrested") is not None
        assert s.get_topic("missing") is None
        assert len(s.list_scenarios()) == 1
        assert len(s.list_directory()) == 1
        print("test_list_and_get passed")

    def test_search() -> None:
        s = ContentStore(_pack())
        results = s.search_topics("search my phone")
        assert results and results[0].id == "privacy-and-phone-searches"
        print("test_search passed")

    def test_ask_grounded_and_refusal() -> None:
        s = ContentStore(_pack())
        good = s.ask("can police search my phone")
        assert good.refused is False and good.citations
        bad = s.ask("weather forecast tomorrow")
        assert bad.refused is True
        print("test_ask_grounded_and_refusal passed")

    test_list_and_get()
    test_search()
    test_ask_grounded_and_refusal()
    print("\nAll tests passed!")
