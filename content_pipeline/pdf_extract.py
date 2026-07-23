"""Extract and normalise plain text from legal-source PDFs (e.g. the Constitution)."""

import logging
import re
from pathlib import Path

# The NDPA copy has malformed cross-reference objects; pypdf logs one per object.
logging.getLogger("pypdf").setLevel(logging.ERROR)

PAGE_MARKER = re.compile(r"--\s*\d+\s*of\s*\d+\s*--")
MULTISPACE = re.compile(r"[ \t\u00a0]+")
MULTINEWLINE = re.compile(r"\n{3,}")


def normalise_whitespace(text: str) -> str:
    """Collapse runs of spaces/tabs and excess blank lines while keeping paragraphs."""
    text = PAGE_MARKER.sub("", text)
    text = text.replace("\r", "\n")
    text = MULTISPACE.sub(" ", text)
    text = "\n".join(line.strip() for line in text.split("\n"))
    text = MULTINEWLINE.sub("\n\n", text)
    return text.strip()


def extract_pages(pdf_path: Path) -> list[str]:
    """Return the extracted text of each page. Requires pypdf."""
    from pypdf import PdfReader

    reader = PdfReader(str(pdf_path))
    return [page.extract_text() or "" for page in reader.pages]


def extract_text(pdf_path: Path) -> str:
    """Extract the full document text, normalised for downstream chunking/search."""
    return normalise_whitespace("\n".join(extract_pages(pdf_path)))


if __name__ == "__main__":

    def test_normalise_collapses_spaces() -> None:
        assert normalise_whitespace("a    b\t c") == "a b c"
        print("test_normalise_collapses_spaces passed")

    def test_normalise_strips_page_markers() -> None:
        assert "of" not in normalise_whitespace("hello -- 5 of 137 -- world").split()
        assert normalise_whitespace("hello -- 5 of 137 -- world") == "hello world"
        print("test_normalise_strips_page_markers passed")

    def test_normalise_limits_blank_lines() -> None:
        assert normalise_whitespace("a\n\n\n\n\nb") == "a\n\nb"
        print("test_normalise_limits_blank_lines passed")

    def test_extract_text_on_real_constitution_if_present() -> None:
        pdf = Path(__file__).resolve().parents[2] / "StartUp" / "Know_your_rights" / "constitution.pdf"
        if not pdf.exists():
            print("test_extract_text_on_real_constitution_if_present skipped (pdf not found)")
            return
        text = extract_text(pdf)
        assert "Fundamental Rights" in text
        assert "personal liberty" in text
        print("test_extract_text_on_real_constitution_if_present passed")

    test_normalise_collapses_spaces()
    test_normalise_strips_page_markers()
    test_normalise_limits_blank_lines()
    test_extract_text_on_real_constitution_if_present()
    print("\nAll tests passed!")
