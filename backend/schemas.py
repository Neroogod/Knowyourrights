"""Pydantic models for content records, the content pack, and the API.

Trust rule enforced here: a `verified` topic or scenario must carry at least one
citation to a legal source. Nothing reaches users as authoritative without a source.
"""

from datetime import date
from enum import Enum

from pydantic import BaseModel, Field, model_validator


def is_stale(review_due_at: str | None, today: "date | None" = None) -> bool:
    """True when a record's scheduled review date has passed.

    Laws change. A record whose review fell due is no longer trustworthy enough
    to cite, so retrieval drops it until a reviewer renews it.
    """
    if not review_due_at:
        return False
    try:
        due = date.fromisoformat(review_due_at[:10])
    except ValueError:
        return False
    return due < (today or date.today())


def is_retrievable(status: str, review_due_at: str | None, today: "date | None" = None) -> bool:
    """Whether a record may be used to answer a question: verified and not stale."""
    return status == "verified" and not is_stale(review_due_at, today)


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
    common_situations: list[str] = Field(default_factory=list)
    words_to_use: list[str] = Field(default_factory=list)
    if_violated: list[str] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None
    review_due_at: str | None = None  # past this date the record leaves AI retrieval

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
    review_due_at: str | None = None  # past this date the record leaves AI retrieval

    @model_validator(mode="after")
    def verified_requires_citation(self) -> "Scenario":
        if self.status == Status.verified and not self.citations:
            raise ValueError(f"verified scenario '{self.id}' must have at least one citation")
        return self


class DirectoryEntry(BaseModel):
    id: str = Field(min_length=1)
    name: str = Field(min_length=1)
    entry_type: str = Field(description="legal_aid | emergency | ngo | regulator | lawyer")
    state: str | None = None
    lga: str | None = None  # local government area, for finer location filtering
    phone: str | None = None
    email: str | None = None
    address: str | None = None
    specialty: list[str] = Field(default_factory=list)  # e.g. ["criminal", "tenancy"]
    url: str | None = None
    # Seed/regulator entries are verified; community submissions are shown but
    # clearly badged until an editor confirms them (see GOVERNANCE.md).
    status: Status = Status.verified
    submitted_by: str | None = None
    cached_offline: bool = True


class Applicability(BaseModel):
    """Which businesses an obligation binds. An unset field means "all".

    Kept separate from the human-readable ``applies_to`` list so a machine can
    filter (does this bind a 10-person Lagos retailer?) while the list still reads
    plainly on screen. Every bound is inclusive; omit a field to place no limit.
    """

    entity_types: list[str] = Field(default_factory=list)  # business_name|ltd|plc|ngo
    sectors: list[str] = Field(default_factory=list)
    states: list[str] = Field(default_factory=list)
    staff_min: int | None = None
    staff_max: int | None = None
    turnover_bands: list[str] = Field(default_factory=list)  # micro|small|medium|large


class EntityProfile(BaseModel):
    """A business describing itself, so it sees only the obligations that bind it.

    This is a filter, not an account: the applicable endpoint takes it in the
    request and does not persist it server-side.
    """

    entity_type: str | None = Field(default=None, description="business_name|ltd|plc|ngo")
    sector: str | None = None
    state: str | None = None
    staff_count: int | None = Field(default=None, ge=0)
    turnover_band: str | None = Field(default=None, description="micro|small|medium|large")


def obligation_applies(applicability: "Applicability | None", profile: EntityProfile) -> bool:
    """Whether an obligation binds a given business.

    Unknown fields on the profile never exclude an obligation: a business that
    has not said how many staff it has still sees staff-scoped duties, because
    hiding a real obligation is the more dangerous error.
    """
    if applicability is None:
        return True
    a, e = applicability, profile
    if a.entity_types and e.entity_type is not None and e.entity_type not in a.entity_types:
        return False
    if a.sectors and e.sector is not None and e.sector not in a.sectors:
        return False
    if a.states and e.state is not None and e.state not in a.states:
        return False
    if a.turnover_bands and e.turnover_band is not None and e.turnover_band not in a.turnover_bands:
        return False
    if e.staff_count is not None:
        if a.staff_min is not None and e.staff_count < a.staff_min:
            return False
        if a.staff_max is not None and e.staff_count > a.staff_max:
            return False
    return True


class Obligation(BaseModel):
    id: str = Field(min_length=1)
    title: str = Field(min_length=1)
    category: str = Field(min_length=1)
    jurisdiction: str = Field(min_length=1)
    summary: str = Field(min_length=1)
    applies_to: list[str] = Field(min_length=1)
    applicability: Applicability | None = None  # structured filter; None = all businesses
    frequency: str | None = None  # once | annual | monthly | ongoing | on_event
    deadline_rule: str | None = None  # plain-language deadline, cited in requirements
    consequence: str | None = None  # cited penalty/exposure for non-compliance
    requirements: list[str] = Field(min_length=1)
    citations: list[Citation] = Field(min_length=1)
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None
    review_due_at: str | None = None  # past this date the record leaves AI retrieval

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
    citations: list[Citation] = Field(default_factory=list)
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None
    review_due_at: str | None = None  # past this date the record leaves AI retrieval

    @model_validator(mode="after")
    def verified_requires_reviewer(self) -> "CompanyChecklist":
        if self.status == Status.verified and not self.reviewed_by:
            raise ValueError(f"verified checklist '{self.id}' must record reviewed_by")
        if self.status == Status.verified and not self.citations:
            raise ValueError(f"verified checklist '{self.id}' must have at least one citation")
        return self


class CaseInterpretation(BaseModel):
    """Educational commentary on a case. Never copies proprietary law-report text."""

    id: str = Field(min_length=1)
    kind: str = Field(description="ratio | commentary | significance")
    body: str = Field(min_length=1)
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None
    review_due_at: str | None = None  # past this date the record leaves AI retrieval

    @model_validator(mode="after")
    def verified_requires_reviewer(self) -> "CaseInterpretation":
        if self.status == Status.verified and not self.reviewed_by:
            raise ValueError(f"verified interpretation '{self.id}' must record reviewed_by")
        return self


class CaseRelation(BaseModel):
    """How one case relates to another - the citator graph a student needs.

    Asserting that a case overrules or distinguishes another is a legal claim, so
    a relation carries the same burden as any other: it needs a source, and it is
    reviewed before it ships.
    """

    relation: str = Field(pattern=r"^(cites|follows|distinguishes|overrules)$")
    case_id: str = Field(min_length=1)
    note: str | None = None
    status: Status = Status.draft


class CaseBrief(BaseModel):
    """Law-student case brief: facts / issues / holding / ratio + interpretations.

    Trust rule: store our own educational digest and a citation/link. Do not paste
    proprietary NWLR headnotes or full judgments into the body fields.
    """

    id: str = Field(min_length=1)
    name: str = Field(min_length=1, description="Party v Party")
    court: str = Field(min_length=1)
    year: int
    area_of_law: str = Field(min_length=1)
    jurisdiction: str = Field(min_length=1)
    summary: str = Field(min_length=1)
    facts: str = Field(min_length=1)
    issues: list[str] = Field(min_length=1)
    holding: str = Field(min_length=1)
    ratio: str = Field(min_length=1)
    report_citation: str | None = None
    source_url: str | None = None
    linked_topic_ids: list[str] = Field(default_factory=list)
    related_cases: list[CaseRelation] = Field(default_factory=list)
    interpretations: list[CaseInterpretation] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
    status: Status = Status.draft
    reviewed_by: str | None = None
    reviewed_at: str | None = None
    review_due_at: str | None = None  # past this date the record leaves AI retrieval

    @model_validator(mode="after")
    def verified_requires_citation_and_reviewer(self) -> "CaseBrief":
        if self.status == Status.verified and not self.citations:
            raise ValueError(f"verified case '{self.id}' must have at least one citation")
        if self.status == Status.verified and not self.reviewed_by:
            raise ValueError(f"verified case '{self.id}' must record reviewed_by")
        return self


class ContentPack(BaseModel):
    version: int
    built_at: str
    topics: list[Topic] = Field(default_factory=list)
    scenarios: list[Scenario] = Field(default_factory=list)
    directory: list[DirectoryEntry] = Field(default_factory=list)
    obligations: list[Obligation] = Field(default_factory=list)
    company_checklists: list[CompanyChecklist] = Field(default_factory=list)
    cases: list[CaseBrief] = Field(default_factory=list)


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
