"""In-memory content store: loads the content pack and serves topics, scenarios,
the directory, search, and the grounded Q&A answerer."""

import json
import os
import sys
from pathlib import Path

_ROOT = str(Path(__file__).resolve().parents[1])
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from backend.content_db import (  # noqa: E402
    DatabaseContentRepository,
    content_repository_from_environment,
)
from backend.rag.answerer import (  # noqa: E402
    COMPANY_REFUSAL,
    STUDENT_REFUSAL,
    ExtractiveAnswerer,
    build_case_documents,
    build_company_documents,
    build_documents,
    generative_answerer_from_environment,
)
from backend.rag.index import Retriever  # noqa: E402
from backend.rag.pgvector import (  # noqa: E402
    PgVectorRetriever,
    embedding_provider_from_environment,
)
from backend.schemas import (  # noqa: E402
    AskResponse,
    CaseBrief,
    CompanyChecklist,
    ContentPack,
    DirectoryEntry,
    EntityProfile,
    Obligation,
    Scenario,
    Topic,
    obligation_applies,
)

DEFAULT_PACK_PATH = Path(__file__).resolve().parents[1] / "data" / "content_pack.json"


class ContentStore:
    """Serves validated content and answers questions over verified topics only."""

    def __init__(
        self,
        pack: ContentPack,
        database_repository: DatabaseContentRepository | None = None,
    ) -> None:
        self._pack = pack
        self._topics: dict[str, Topic] = {t.id: t for t in pack.topics}
        self._scenarios: dict[str, Scenario] = {s.id: s for s in pack.scenarios}
        self._directory: list[DirectoryEntry] = list(pack.directory)
        self._obligations: dict[str, Obligation] = {item.id: item for item in pack.obligations}
        self._company_checklists: dict[str, CompanyChecklist] = {
            item.id: item for item in pack.company_checklists
        }
        self._cases: dict[str, CaseBrief] = {item.id: item for item in pack.cases}

        documents = build_documents(pack.topics)
        production_ai = os.getenv("KYR_AI_PRODUCTION_ENABLED") == "1"
        embedding_provider = embedding_provider_from_environment() if database_repository else None
        if production_ai and (database_repository is None or embedding_provider is None):
            raise RuntimeError(
                "production AI requires PostgreSQL content and a configured embedding provider"
            )
        self._retriever = (
            PgVectorRetriever(database_repository, embedding_provider, "topic")
            if database_repository and embedding_provider
            else Retriever(documents)
        )
        if production_ai and isinstance(self._retriever, PgVectorRetriever):
            total, embedded = database_repository.embedding_coverage(self._retriever.model_id)
            if total == 0 or embedded != total:
                raise RuntimeError(
                    "production AI is blocked until every verified active chunk is embedded "
                    f"with the configured model ({embedded}/{total})"
                )
        rights_fallback = ExtractiveAnswerer(self._retriever)
        self._answerer = generative_answerer_from_environment(
            self._retriever,
            rights_fallback,
        )
        company_documents = build_company_documents(pack.obligations)
        company_retriever = (
            PgVectorRetriever(database_repository, embedding_provider, "obligation")
            if database_repository and embedding_provider
            else Retriever(company_documents)
        )
        company_fallback = ExtractiveAnswerer(
            company_retriever,
            refusal=COMPANY_REFUSAL,
        )
        self._company_answerer = generative_answerer_from_environment(
            company_retriever,
            company_fallback,
            refusal=COMPANY_REFUSAL,
        )
        case_documents = build_case_documents(pack.cases)
        case_retriever = (
            PgVectorRetriever(database_repository, embedding_provider, "case")
            if database_repository and embedding_provider
            else Retriever(case_documents)
        )
        student_fallback = ExtractiveAnswerer(
            case_retriever,
            min_score=0.2,
            refusal=STUDENT_REFUSAL,
        )
        self._student_answerer = generative_answerer_from_environment(
            case_retriever,
            student_fallback,
            refusal=STUDENT_REFUSAL,
        )

    @classmethod
    def from_file(cls, path: Path = DEFAULT_PACK_PATH) -> "ContentStore":
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls(ContentPack.model_validate(data))

    @classmethod
    def from_environment(cls, path: Path = DEFAULT_PACK_PATH) -> "ContentStore":
        """Use PostgreSQL content when configured, retaining JSON for offline development."""
        repository = content_repository_from_environment()
        if repository is None:
            return cls.from_file(path)
        pack = repository.load_active_pack()
        if pack is None and os.getenv("KYR_CONTENT_AUTO_IMPORT") == "1":
            source_pack = ContentPack.model_validate(json.loads(path.read_text(encoding="utf-8")))
            repository.import_pack(source_pack)
            pack = repository.load_active_pack()
        if pack is None:
            raise RuntimeError(
                "database content backend has no active content version; run the content import command"
            )
        return cls(pack, database_repository=repository)

    @property
    def version(self) -> int:
        return self._pack.version

    def list_topics(
        self,
        category: str | None = None,
        jurisdiction: str | None = None,
        status: str | None = None,
    ) -> list[Topic]:
        topics = list(self._topics.values())
        if category:
            topics = [t for t in topics if t.category == category]
        if jurisdiction:
            topics = [t for t in topics if t.jurisdiction == jurisdiction]
        if status:
            topics = [t for t in topics if t.status.value == status]
        return topics

    def categories(self) -> list[dict]:
        """Topic categories present in the pack, each with a live count."""
        counts: dict[str, int] = {}
        for topic in self._topics.values():
            counts[topic.category] = counts.get(topic.category, 0) + 1
        return [
            {"id": name, "name": name.replace("-", " ").capitalize(), "topic_count": count}
            for name, count in sorted(counts.items())
        ]

    def get_topic(self, topic_id: str) -> Topic | None:
        return self._topics.get(topic_id)

    def list_scenarios(self) -> list[Scenario]:
        return list(self._scenarios.values())

    def get_scenario(self, scenario_id: str) -> Scenario | None:
        return self._scenarios.get(scenario_id)

    def list_directory(
        self,
        entry_type: str | None = None,
        state: str | None = None,
        lga: str | None = None,
        specialty: str | None = None,
        near: str | None = None,
    ) -> list[DirectoryEntry]:
        """Filter the directory, and sort so nearby help surfaces first.

        `near` is the user's state. It does not exclude anything - a lawyer two
        states away is still better than none - it just floats matching-state
        entries (and Federal, which is nationwide) to the top.
        """
        entries = list(self._directory)
        if entry_type:
            entries = [e for e in entries if e.entry_type == entry_type]
        if state:
            entries = [e for e in entries if e.state == state]
        if lga:
            entries = [e for e in entries if e.lga == lga]
        if specialty:
            entries = [e for e in entries if specialty in e.specialty]

        if near:

            def rank(entry: DirectoryEntry) -> int:
                if entry.state == near:
                    return 0
                if entry.state == "Federal":  # nationwide bodies are always relevant
                    return 1
                return 2

            entries.sort(key=rank)
        return entries

    def list_obligations(self) -> list[Obligation]:
        return list(self._obligations.values())

    def get_obligation(self, obligation_id: str) -> Obligation | None:
        return self._obligations.get(obligation_id)

    def list_company_checklists(self) -> list[CompanyChecklist]:
        return list(self._company_checklists.values())

    def applicable_for(self, profile: EntityProfile) -> dict:
        """Obligations and checklists that bind a given business profile.

        A checklist is included when any obligation it links is applicable, so a
        starter checklist does not vanish just because one of its steps does not
        apply to this particular business.
        """
        obligations = [
            item for item in self._obligations.values() if obligation_applies(item.applicability, profile)
        ]
        applicable_ids = {item.id for item in obligations}
        checklists = [
            checklist
            for checklist in self._company_checklists.values()
            if not checklist.items
            or any(step.obligation_id in applicable_ids for step in checklist.items if step.obligation_id)
            or all(step.obligation_id is None for step in checklist.items)
        ]
        return {"obligations": obligations, "checklists": checklists}

    def list_cases(
        self,
        area_of_law: str | None = None,
        year: int | None = None,
        court: str | None = None,
    ) -> list[CaseBrief]:
        cases = list(self._cases.values())
        if area_of_law:
            cases = [c for c in cases if c.area_of_law == area_of_law]
        if year is not None:
            cases = [c for c in cases if c.year == year]
        if court:
            cases = [c for c in cases if c.court == court]
        return cases

    def case_filters(self) -> dict:
        """The filter values actually present in the library, for the UI to offer."""
        cases = list(self._cases.values())
        return {
            "areas_of_law": sorted({c.area_of_law for c in cases}),
            "courts": sorted({c.court for c in cases}),
            "years": sorted({c.year for c in cases}, reverse=True),
        }

    def related_cases(self, case_id: str) -> list[dict]:
        """Resolve a case's citator relations to cases actually in the library."""
        case = self._cases.get(case_id)
        if case is None:
            return []
        resolved = []
        for relation in case.related_cases:
            other = self._cases.get(relation.case_id)
            if other is None:
                continue
            resolved.append(
                {
                    "relation": relation.relation,
                    "case_id": other.id,
                    "name": other.name,
                    "court": other.court,
                    "year": other.year,
                    "note": relation.note,
                    "status": relation.status.value,
                }
            )
        return resolved

    def get_case(self, case_id: str) -> CaseBrief | None:
        return self._cases.get(case_id)

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

    def ask_students(self, question: str) -> AskResponse:
        return self._student_answerer.answer(question)


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
