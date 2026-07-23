"""Registry of the legal sources the pipeline may ingest.

Every authoritative statement in the product resolves to one of these. The
registry exists so the pipeline is no longer hardcoded to a single Constitution
PDF: each source declares how it is cited, which jurisdiction it belongs to, and
which audience it serves, so retrieval can be scoped (a tax duty must never be
cited to the Constitution).
"""

from dataclasses import dataclass
from pathlib import Path

SEED_DIR = Path(__file__).resolve().parents[2] / "StartUp" / "Know_your_rights"

# Who a source speaks to. The RAG audience guard uses this so business questions
# retrieve business statutes and rights questions do not surface company law.
AUDIENCE_INDIVIDUAL = "individual"
AUDIENCE_BUSINESS = "business"
AUDIENCE_BOTH = "both"


@dataclass(frozen=True)
class LegalSource:
    """One legal document the pipeline can parse and cite."""

    id: str
    name: str  # exact string used as Citation.source_name
    short_name: str  # compact display form, e.g. "CAMA 2020"
    source_type: str  # constitution | act
    jurisdiction: str
    filename: str  # file inside the seed directory
    audience: str
    is_authoritative: bool = True
    max_section: int | None = None  # sanity bound for section parsing
    # (section number, text that must appear in it) - spot checks that catch a
    # document whose sections parse but attach the wrong body to a locator.
    probes: tuple[tuple[int, str], ...] = ()
    notes: str = ""

    def path(self, seed_dir: Path = SEED_DIR) -> Path:
        """Absolute path to this source's document."""
        return seed_dir / self.filename

    def exists(self, seed_dir: Path = SEED_DIR) -> bool:
        return self.path(seed_dir).exists()

    def locator(self, section: int | str) -> str:
        """Citation locator for a section, e.g. 's.35'."""
        return f"s.{section}"


REGISTRY: tuple[LegalSource, ...] = (
    LegalSource(
        id="constitution-1999",
        name="1999 Constitution of the Federal Republic of Nigeria",
        short_name="1999 Constitution",
        source_type="constitution",
        jurisdiction="NG-Federal",
        filename="constitution.pdf",
        audience=AUDIENCE_BOTH,
        max_section=320,
        probes=((35, "personal liberty"), (37, "privacy")),
        notes=(
            "This PDF loses inline section/subsection numbering in Chapter IV, so bodies "
            "misattach to locators; shipped rights citations are hand-authored, not parsed."
        ),
    ),
    LegalSource(
        id="interpretation-act",
        name="Interpretation Act",
        short_name="Interpretation Act",
        source_type="act",
        jurisdiction="NG-Federal",
        filename="NGA1652.pdf",
        audience=AUDIENCE_BOTH,
        max_section=40,
    ),
    LegalSource(
        id="cama-2020",
        name="Companies and Allied Matters Act 2020",
        short_name="CAMA 2020",
        source_type="act",
        jurisdiction="NG-Federal",
        filename="CAMA-2020.pdf",
        audience=AUDIENCE_BUSINESS,
        max_section=870,
        probes=((421, "annual return"), (222, "charge")),
        notes=(
            "Verified as the 2020 Act (870 sections; includes LLPs). "
            "Not a gazette print - confirm in review."
        ),
    ),
    LegalSource(
        id="ndpa-2023",
        name="Nigeria Data Protection Act 2023",
        short_name="NDPA 2023",
        source_type="act",
        jurisdiction="NG-Federal",
        filename="NDPA-2023.pdf",
        audience=AUDIENCE_BUSINESS,
        max_section=65,
        probes=((24, "personal data"),),
        notes="Text layer is noisy in the schedule; check extracted sections before citing.",
    ),
)


def source_by_id(source_id: str) -> LegalSource:
    """Look up a source, raising if it is not registered."""
    for s in REGISTRY:
        if s.id == source_id:
            return s
    raise KeyError(f"unknown source id: {source_id!r}")


def sources_for_audience(audience: str) -> list[LegalSource]:
    """Sources that may be cited to a given audience ('both' always qualifies)."""
    if audience not in (AUDIENCE_INDIVIDUAL, AUDIENCE_BUSINESS, AUDIENCE_BOTH):
        raise ValueError(f"unknown audience: {audience!r}")
    if audience == AUDIENCE_BOTH:
        return list(REGISTRY)
    return [s for s in REGISTRY if s.audience in (audience, AUDIENCE_BOTH)]


def available_sources(seed_dir: Path = SEED_DIR) -> list[LegalSource]:
    """Registered sources whose document is actually present on disk."""
    return [s for s in REGISTRY if s.exists(seed_dir)]


if __name__ == "__main__":

    def test_lookup_and_unknown() -> None:
        assert source_by_id("cama-2020").short_name == "CAMA 2020"
        try:
            source_by_id("nope")
            raise AssertionError("expected KeyError")
        except KeyError:
            pass
        print("test_lookup_and_unknown passed")

    def test_ids_and_filenames_unique() -> None:
        assert len({s.id for s in REGISTRY}) == len(REGISTRY)
        assert len({s.filename for s in REGISTRY}) == len(REGISTRY)
        print("test_ids_and_filenames_unique passed")

    def test_audience_scoping() -> None:
        business = {s.id for s in sources_for_audience(AUDIENCE_BUSINESS)}
        individual = {s.id for s in sources_for_audience(AUDIENCE_INDIVIDUAL)}
        assert "cama-2020" in business and "ndpa-2023" in business
        # Company law must never be offered as an answer to a rights question.
        assert "cama-2020" not in individual and "ndpa-2023" not in individual
        # Shared sources reach everyone.
        assert "constitution-1999" in business and "constitution-1999" in individual
        print("test_audience_scoping passed")

    def test_bad_audience_rejected() -> None:
        try:
            sources_for_audience("lawyers")
            raise AssertionError("expected ValueError")
        except ValueError:
            pass
        print("test_bad_audience_rejected passed")

    def test_locator_format() -> None:
        assert source_by_id("cama-2020").locator(421) == "s.421"
        print("test_locator_format passed")

    def test_registry_matches_shipped_citations() -> None:
        # Content already cites the Constitution by this exact string; the registry
        # must not drift from it or citations stop resolving.
        assert source_by_id("constitution-1999").name == (
            "1999 Constitution of the Federal Republic of Nigeria"
        )
        print("test_registry_matches_shipped_citations passed")

    test_lookup_and_unknown()
    test_ids_and_filenames_unique()
    test_audience_scoping()
    test_bad_audience_rejected()
    test_locator_format()
    test_registry_matches_shipped_citations()
    print(f"\nAvailable on disk: {[s.id for s in available_sources()]}")
    print("All tests passed!")
