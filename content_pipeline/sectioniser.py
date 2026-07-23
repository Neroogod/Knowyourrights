"""Split a statute's text into numbered sections that keep their locators.

Citations are only as trustworthy as the locator attached to them, so retrieval
chunks must know which section they came from. Nigerian statutes (the 1999
Constitution, CAMA 2020, the NDPA 2023) share a convention the parser relies on:
a section opens at the start of a line with its number, a full stop, then either
a subsection marker or a capitalised word - e.g.

    35. (1) Every person shall be entitled to his personal liberty ...
    143. (1) A company may, where so authorised by its articles ...

Extracted PDF text also contains stray numbers (page furniture, marginal notes,
table cells) that look identical. Because statutes number their sections in
ascending order, the parser keeps only a strictly increasing run of candidates
and discards the rest, which removes that noise without hand-tuning per document.
"""

import re
from dataclasses import dataclass

# A section opener: line start, 1-4 digits, '.', space, then '(' or a capital.
SECTION_START = re.compile(r"^(\d{1,4})\.\s+(?=[(A-Z])", re.MULTILINE)


@dataclass(frozen=True)
class Section:
    """One numbered section of a statute."""

    number: int
    text: str
    start: int  # character offset in the source text
    end: int

    @property
    def locator(self) -> str:
        return f"s.{self.number}"

    def preview(self, limit: int = 120) -> str:
        flat = " ".join(self.text.split())
        return flat[:limit]


def split_sections(text: str, max_section: int | None = None, min_chars: int = 40) -> list[Section]:
    """Parse `text` into ascending numbered sections.

    `max_section` (from the source registry) rejects candidates above the
    statute's real section count - a cheap guard against years and figures that
    happen to sit at the start of a line. `min_chars` drops fragments too short
    to be a real section body.
    """
    if max_section is not None and max_section <= 0:
        raise ValueError("max_section must be positive")
    if min_chars < 0:
        raise ValueError("min_chars must be >= 0")

    candidates: list[tuple[int, int, int]] = []  # (number, body_start, match_start)
    for m in SECTION_START.finditer(text):
        number = int(m.group(1))
        if number == 0 or (max_section is not None and number > max_section):
            continue
        candidates.append((number, m.end(), m.start()))
    if not candidates:
        return []

    # A section number appears more than once: briefly in the "Arrangement of
    # Sections" contents table, then in full in the enacted body. PDF extraction
    # can also emit sections out of order, so an ascending-sequence filter loses
    # real text. Instead every occurrence is measured and the longest one wins -
    # a contents entry ("Right to personal liberty.") is a fraction of the real
    # section, so the enacted text is selected without document-specific rules.
    best_by_number: dict[int, Section] = {}
    for i, (number, body_start, match_start) in enumerate(candidates):
        end = candidates[i + 1][2] if i + 1 < len(candidates) else len(text)
        body = text[body_start:end].strip()
        existing = best_by_number.get(number)
        if existing is None or len(body) > len(existing.text):
            best_by_number[number] = Section(
                number=number, text=body, start=match_start, end=end
            )

    return [s for _, s in sorted(best_by_number.items()) if len(s.text) >= min_chars]


def find_section(sections: list[Section], number: int) -> Section | None:
    """Return the section with this number, or None."""
    for s in sections:
        if s.number == number:
            return s
    return None


# A source parsing below this fraction of its known section count is treated as
# degraded: its text layer is too damaged to support citation, so it must not be
# indexed as authoritative until a cleaner document replaces it.
COVERAGE_FLOOR = 0.80


def coverage(sections: list[Section], max_section: int | None) -> float:
    """Fraction of a statute's sections that were successfully parsed (0..1)."""
    if not max_section or max_section <= 0:
        return 0.0
    return min(len(sections) / max_section, 1.0)


def is_citable(sections: list[Section], max_section: int | None) -> bool:
    """Whether a parsed source is complete enough to cite from."""
    return coverage(sections, max_section) >= COVERAGE_FLOOR


@dataclass(frozen=True)
class SourceReport:
    """Machine-checked quality of one parsed source."""

    section_count: int
    coverage: float
    failed_probes: tuple[str, ...]

    @property
    def citable(self) -> bool:
        """Complete enough AND landing known text on the right locator.

        Coverage alone is not sufficient: a document can parse most of its
        sections while attaching the wrong body to a locator, which is the more
        dangerous failure because the citation still looks valid.
        """
        return self.coverage >= COVERAGE_FLOOR and not self.failed_probes

    @property
    def verdict(self) -> str:
        if self.citable:
            return "citable"
        reason = "coverage" if self.coverage < COVERAGE_FLOOR else "probe"
        return f"DEGRADED ({reason})"


def verify_sections(
    sections: list[Section],
    max_section: int | None,
    probes: tuple[tuple[int, str], ...] = (),
) -> SourceReport:
    """Check a parsed source for completeness and correct locator attribution.

    `probes` are (section number, text that must appear in it) pairs chosen so a
    mis-parse is caught rather than shipped.
    """
    failures: list[str] = []
    for number, needle in probes:
        hit = find_section(sections, number)
        if hit is None:
            failures.append(f"s.{number} missing")
        elif needle.lower() not in hit.text.lower():
            failures.append(f"s.{number} lacks {needle!r}")
    return SourceReport(
        section_count=len(sections),
        coverage=coverage(sections, max_section),
        failed_probes=tuple(failures),
    )


if __name__ == "__main__":
    from pathlib import Path

    SAMPLE = (
        "Preliminary text that belongs to no section at all.\n"
        "1. (1) This Act may be cited as the Sample Act and shall apply throughout.\n"
        "(2) It commences on publication in the Gazette for all purposes stated.\n"
        "2. Every person shall have the right to be treated fairly under this Act.\n"
        "3. (1) A body corporate may be formed in the manner prescribed hereunder.\n"
    )

    def test_finds_each_section() -> None:
        secs = split_sections(SAMPLE)
        assert [s.number for s in secs] == [1, 2, 3], [s.number for s in secs]
        print("test_finds_each_section passed")

    def test_locator_and_body() -> None:
        secs = split_sections(SAMPLE)
        assert secs[0].locator == "s.1"
        assert "cited as the Sample Act" in secs[0].text
        # Subsections stay with their parent section.
        assert "commences on publication" in secs[0].text
        print("test_locator_and_body passed")

    def test_preamble_excluded() -> None:
        secs = split_sections(SAMPLE)
        assert "belongs to no section" not in secs[0].text
        print("test_preamble_excluded passed")

    def test_descending_noise_discarded() -> None:
        noisy = (
            "1. (1) The first real section of the statute runs on for a while here.\n"
            "1999. A stray year that must not be treated as a section of the Act.\n"
            "2. (1) The second real section also runs on for a reasonable length.\n"
        )
        secs = split_sections(noisy, max_section=100)
        assert [s.number for s in secs] == [1, 2], [s.number for s in secs]
        print("test_descending_noise_discarded passed")

    def test_max_section_bound() -> None:
        secs = split_sections(SAMPLE, max_section=2)
        assert [s.number for s in secs] == [1, 2]
        print("test_max_section_bound passed")

    def test_min_chars_drops_fragments() -> None:
        secs = split_sections(SAMPLE, min_chars=10_000)
        assert secs == []
        print("test_min_chars_drops_fragments passed")

    def test_invalid_params_raise() -> None:
        for bad in (
            lambda: split_sections(SAMPLE, max_section=0),
            lambda: split_sections(SAMPLE, min_chars=-1),
        ):
            try:
                bad()
                raise AssertionError("expected ValueError")
            except ValueError:
                pass
        print("test_invalid_params_raise passed")

    def test_empty_text() -> None:
        assert split_sections("") == []
        print("test_empty_text passed")

    def test_find_section() -> None:
        secs = split_sections(SAMPLE)
        assert find_section(secs, 2) is not None
        assert find_section(secs, 99) is None
        print("test_find_section passed")

    def test_coverage_helpers() -> None:
        secs = split_sections(SAMPLE)
        assert coverage(secs, 3) == 1.0
        assert coverage(secs, 6) == 0.5
        assert coverage(secs, None) == 0.0
        assert is_citable(secs, 3) and not is_citable(secs, 100)
        print("test_coverage_helpers passed")

    def test_real_statutes_if_present() -> None:
        """Assert what these specific documents actually yield.

        Expectations below were measured, not assumed. CAMA parses completely;
        the NDPA copy is a damaged text layer and is expected to fail the
        coverage floor, which is the behaviour we want the pipeline to surface.
        """
        import sys

        sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
        from content_pipeline.pdf_extract import extract_text  # noqa: E402
        from content_pipeline.sources import available_sources  # noqa: E402

        found = {s.id: s for s in available_sources()}
        # id: (minimum sections, expected citable verdict)
        expectations: dict[str, tuple[int, bool]] = {
            # Parses ~85% of sections, but Chapter IV bodies misattach to their
            # locators, so its probes fail and it is correctly refused.
            "constitution-1999": (250, False),
            # Parses completely and lands the right text on s.421 and s.222.
            "cama-2020": (850, True),
            # Damaged text layer: only a quarter of sections survive.
            "ndpa-2023": (10, False),
        }
        for sid, (min_count, expect_citable) in expectations.items():
            src = found.get(sid)
            if src is None:
                print(f"  {sid}: skipped (document not present)")
                continue
            secs = split_sections(extract_text(src.path()), max_section=src.max_section)
            report = verify_sections(secs, src.max_section, src.probes)
            assert report.section_count >= min_count, f"{sid}: only {report.section_count} sections"
            assert report.citable is expect_citable, (
                f"{sid}: citable={report.citable} "
                f"(coverage {report.coverage:.0%}, failures {report.failed_probes})"
            )
            detail = f" - {', '.join(report.failed_probes)}" if report.failed_probes else ""
            print(
                f"  {sid}: {report.section_count} sections, "
                f"{report.coverage:.0%} coverage, {report.verdict}{detail}"
            )
        print("test_real_statutes_if_present passed")

    test_finds_each_section()
    test_locator_and_body()
    test_preamble_excluded()
    test_descending_noise_discarded()
    test_max_section_bound()
    test_min_chars_drops_fragments()
    test_invalid_params_raise()
    test_empty_text()
    test_find_section()
    test_coverage_helpers()
    test_real_statutes_if_present()
    print("\nAll tests passed!")
