"""Administrative commands for importing and activating versioned content packs."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from backend.content_db import DatabaseContentRepository
from backend.content_store import DEFAULT_PACK_PATH
from backend.rag.pgvector import embedding_provider_from_environment, reembed_active_content
from backend.schemas import ContentPack


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["import", "reembed"])
    parser.add_argument("--file", type=Path, default=DEFAULT_PACK_PATH)
    parser.add_argument(
        "--database-url",
        default=os.getenv("CONTENT_DATABASE_URL") or os.getenv("DATABASE_URL"),
    )
    parser.add_argument("--inactive", action="store_true")
    args = parser.parse_args()
    if not args.database_url:
        parser.error("--database-url, CONTENT_DATABASE_URL, or DATABASE_URL is required")
    repository = DatabaseContentRepository(args.database_url)
    if args.command == "import":
        pack = ContentPack.model_validate(json.loads(args.file.read_text(encoding="utf-8")))
        version_id = repository.import_pack(pack, activate=not args.inactive)
        print(f"Imported content version {pack.version} as {version_id}")
        return
    provider = embedding_provider_from_environment()
    if provider is None:
        parser.error(
            "embedding provider is unavailable; install sentence-transformers for local "
            "embeddings or configure OPENAI_API_KEY"
        )
    count = reembed_active_content(repository, provider)
    print(f"Embedded {count} active content chunks")


if __name__ == "__main__":
    main()
