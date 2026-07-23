"""Pydantic models for content records, the content pack, and the API.

Trust rule enforced here: a `verified` topic or scenario must carry at least one
citation to a legal source. Nothing reaches users as authoritative without a source.
"""

from enum import Enum

from pydantic import BaseModel, Field, model_validator


class Status(str, Enum):
    draft = "draft"
    community = "community"
    verified = "verified"


class Citation(BaseModel):
    source_name: str = Field(min_length=1)
    locator: str = Field(min_length=1, description="e.g. 's.35(2)'")
    quote: str | None = None
    url: str | None = None


class Topic(BaseModel):
    id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    category: str = Field(min_length=1)
    jurisdiction: str = Field(min_length=1)
    summary: str = Field(min_length=1)
    body_plain: str = Field(min_length=1)
    rights: list[str] = Field(default_factory=list)
    do_list: list[str] = Field(default_factory=list)
    dont_list: list[str] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None

    @model_validator(mode="after")
    def verified_requires_citation(self) -> "Topic":
        if self.status == Status.verified and not self.citations:
            raise ValueError(f"verified topic '{self.id}' must have at least one citation")
        if self.status == Status.verified and not self.reviewed_by:
            raise ValueError(f"verified topic '{self.id}' must record reviewed_by")
        return self


class ScenarioStep(BaseModel):
    text: str = Field(min_length=1)
    action: str | None = Field(default=None, description="optional: call | script | link")
    value: str | None = None


class Scenario(BaseModel):
    id: str = Field(min_length=1)
    trigger: str = Field(min_length=1)
    description: str = Field(min_length=1)
    jurisdiction: str = Field(min_length=1)
    steps: list[ScenarioStep] = Field(min_length=1)
    linked_topic_ids: list[str] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
    offline_priority: bool = True
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None

    @model_validator(mode="after")
    def verified_requires_citation(self) -> "Scenario":
        if self.status == Status.verified and not self.citations:
            raise ValueError(f"verified scenario '{self.id}' must have at least one citation")
        return self


class DirectoryEntry(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    entry_type: str = Field(description="legal_aid | emergency | ngo")
    state: str | None = None
    phone: str | None = None
    url: str | None = None
    cached_offline: bool = True


class Obligation(BaseModel):
    id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    category: str = Field(min_length=1)
    jurisdiction: str = Field(min_length=1)
    summary: str = Field(min_length=1)
    applies_to: list[str] = Field(min_length=1)
    requirements: list[str] = Field(min_length=1)
    citations: list[Citation] = Field(min_length=1)
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None

    @model_validator(mode="after")
    def verified_requires_reviewer(self) -> "Obligation":
        if self.status == Status.verified and not self.reviewed_by:
            raise ValueError(f"verified obligation '{self.id}' must record reviewed_by")
        return self


class ChecklistItem(BaseModel):
    text: str = Field(min_length=1)
    obligation_id: str | None = None


class CompanyChecklist(BaseModel):
    id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    description: str = Field(min_length=1)
    jurisdiction: str = Field(min_length=1)
    items: list[ChecklistItem] = Field(min_length=1)
    citations: list[Citation] = Field(min_length=1)
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None

    @model_validator(mode="after")
    def verified_requires_reviewer(self) -> "CompanyChecklist":
        if self.status == Status.verified and not self.reviewed_by:
            raise ValueError(f"verified checklist '{self.id}' must record reviewed_by")
        return self


class ContentPack(BaseModel):
    version: int
    built_at: str
    topics: list[Topic] = Field(default_factory=list)
    scenarios: list[Scenario] = Field(default_factory=list)
    directory: list[DirectoryEntry] = Field(default_factory=list)
    obligations: list[Obligation] = Field(default_factory=list)
    company_checklists: list[CompanyChecklist] = Field(default_factory=list)


class AskRequest(BaseModel):
    question: str = Field(min_length=1, max_length=500)


class AnswerCitation(BaseModel):
    source_name: str
    locator: str
    quote: str | None = None
    url: str | None = None


class AskResponse(BaseModel):
    refused: bool
    answer: str
    citations: list[AnswerCitation] = Field(default_factory=list)
    related_topic_ids: list[str] = Field(default_factory=list)
    disclaimer: str


if __name__ == "__main__":

    def test_verified_topic_requires_citation() -> None:
        try:
            Topic(
                id="t",
                title="T",
                category="c",
                jurisdiction="NG",
                summary="s",
                body_plain="b",
                status=Status.verified,
                reviewed_by="Lawyer",
            )
            raise AssertionError("expected ValueError")
        except ValueError:
            pass
        print("test_verified_topic_requires_citation passed")

    def test_verified_topic_ok_with_citation() -> None:
        t = Topic(
            id="t",
            title="T",
            category="c",
            jurisdiction="NG",
            summary="s",
            body_plain="b",
            status=Status.verified,
            reviewed_by="Lawyer",
            citations=[Citation(source_name="1999 Constitution", locator="s.35")],
        )
        assert t.status == Status.verified
        print("test_verified_topic_ok_with_citation passed")

    def test_scenario_needs_steps() -> None:
        try:
            Scenario(id="s", trigger="x", description="d", jurisdiction="NG", steps=[])
            raise AssertionError("expected ValueError")
        except ValueError:
            pass
        print("test_scenario_needs_steps passed")

    def test_draft_topic_allows_no_citation() -> None:
        t = Topic(id="t", title="T", category="c", jurisdiction="NG", summary="s", body_plain="b")
        assert t.status == Status.draft
        print("test_draft_topic_allows_no_citation passed")

    test_verified_topic_requires_citation()
    test_verified_topic_ok_with_citation()
    test_scenario_needs_steps()
    test_draft_topic_allows_no_citation()
    print("\nAll tests passed!")
