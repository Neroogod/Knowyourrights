"""Build the versioned content pack from authored content and legal sources.

Loads and validates every topic/scenario/directory record (pydantic enforces the
"verified needs a citation" rule), extracts the Constitution text as a raw source,
and writes a single content_pack.json the backend and app consume.
"""

import json
import sys
from datetime import date
from pathlib import Path

BACKEND_ON_PATH = str(Path(__file__).resolve().parents[1])
if BACKEND_ON_PATH not in sys.path:
    sys.path.insert(0, BACKEND_ON_PATH)

from backend.schemas import ContentPack, DirectoryEntry, Scenario, Topic  # noqa: E402
from content_pipeline.pdf_extract import extract_text  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[1]
CONTENT_DIR = REPO_ROOT / "content"
DATA_DIR = REPO_ROOT / "data"
CONSTITUTION_PDF = REPO_ROOT.parent / "StartUp" / "Know_your_rights" / "constitution.pdf"


def _load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def load_topics(content_dir: Path) -> list[Topic]:
    """Load and validate every topic JSON in content/topics."""
    return [Topic.model_validate(_load_json(p)) for p in sorted((content_dir / "topics").glob("*.json"))]


def load_scenarios(content_dir: Path) -> list[Scenario]:
    """Load and validate every scenario JSON in content/scenarios."""
    paths = sorted((content_dir / "scenarios").glob("*.json"))
    return [Scenario.model_validate(_load_json(p)) for p in paths]


def load_directory(content_dir: Path) -> list[DirectoryEntry]:
    """Load directory entries; each file may hold a single object or a list."""
    entries: list[DirectoryEntry] = []
    for path in sorted((content_dir / "directory").glob("*.json")):
        data = _load_json(path)
        rows = data if isinstance(data, list) else [data]
        entries.extend(DirectoryEntry.model_validate(row) for row in rows)
    return entries


def build_pack(content_dir: Path = CONTENT_DIR, version: int = 1) -> ContentPack:
    """Assemble and validate the full content pack."""
    return ContentPack(
        version=version,
        built_at=date.today().isoformat(),
        topics=load_topics(content_dir),
        scenarios=load_scenarios(content_dir),
        directory=load_directory(content_dir),
    )


def extract_constitution_source(pdf_path: Path, out_path: Path) -> int:
    """Extract the Constitution text to a raw source file. Returns character count."""
    text = extract_text(pdf_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text, encoding="utf-8")
    return len(text)


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    pack = build_pack()
    pack_path = DATA_DIR / "content_pack.json"
    pack_path.write_text(pack.model_dump_json(indent=2), encoding="utf-8")

    verified_topics = sum(1 for t in pack.topics if t.status.value == "verified")
    print(f"Wrote {pack_path}")
    print(f"  topics: {len(pack.topics)} ({verified_topics} verified)")
    print(f"  scenarios: {len(pack.scenarios)}")
    print(f"  directory: {len(pack.directory)}")

    if CONSTITUTION_PDF.exists():
        chars = extract_constitution_source(CONSTITUTION_PDF, DATA_DIR / "sources" / "constitution.txt")
        print(f"  extracted Constitution source: {chars} chars")
    else:
        print("  Constitution PDF not found; skipped source extraction")


if __name__ == "__main__":
    # When run directly, run self-tests unless asked to actually build (--run).
    if "--run" in sys.argv:
        main()
        sys.exit(0)

    import tempfile

    def _write(path: Path, obj: object) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(obj), encoding="utf-8")

    def test_build_pack_loads_and_validates() -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write(
                root / "topics" / "t.json",
                {
                    "id": "t",
                    "title": "T",
                    "category": "c",
                    "jurisdiction": "NG",
                    "summary": "s",
                    "body_plain": "b",
                    "status": "verified",
                    "reviewed_by": "L",
                    "citations": [{"source_name": "1999 Constitution", "locator": "s.35"}],
                },
            )
            _write(
                root / "scenarios" / "s.json",
                {
                    "id": "s",
                    "trigger": "x",
                    "description": "d",
                    "jurisdiction": "NG",
                    "steps": [{"text": "step one"}],
                },
            )
            _write(
                root / "directory" / "d.json",
                [{"id": "d1", "name": "Legal Aid", "entry_type": "legal_aid"}],
            )
            pack = build_pack(root, version=2)
            assert pack.version == 2
            assert len(pack.topics) == 1 and len(pack.scenarios) == 1 and len(pack.directory) == 1
        print("test_build_pack_loads_and_validates passed")

    def test_build_pack_rejects_uncited_verified_topic() -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write(
                root / "topics" / "bad.json",
                {
                    "id": "bad",
                    "title": "T",
                    "category": "c",
                    "jurisdiction": "NG",
                    "summary": "s",
                    "body_plain": "b",
                    "status": "verified",
                    "reviewed_by": "L",
                },
            )
            try:
                build_pack(root)
                raise AssertionError("expected validation error")
            except ValueError:
                pass
        print("test_build_pack_rejects_uncited_verified_topic passed")

    def test_real_content_builds() -> None:
        pack = build_pack()
        assert len(pack.topics) >= 5, "expected the authored seed topics"
        assert all(t.citations for t in pack.topics if t.status.value == "verified")
        print("test_real_content_builds passed")

    test_build_pack_loads_and_validates()
    test_build_pack_rejects_uncited_verified_topic()
    test_real_content_builds()
    print("\nAll tests passed! (use --run to build the pack)")
