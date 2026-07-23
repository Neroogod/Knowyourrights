"""Shared fixtures: an in-memory ContentStore and TestClient (no disk/network)."""

import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

_ROOT = str(Path(__file__).resolve().parents[2])
if _ROOT not in sys.path:
    sys.path.insert(0, _ROOT)

from backend.accounts import AccountService, DevelopmentGateway  # noqa: E402
from backend.api import create_app  # noqa: E402
from backend.content_store import ContentStore  # noqa: E402
from backend.schemas import (  # noqa: E402
    ChecklistItem,
    Citation,
    CompanyChecklist,
    ContentPack,
    DirectoryEntry,
    Obligation,
    Scenario,
    ScenarioStep,
    Status,
    Topic,
)


def _sample_pack() -> ContentPack:
    return ContentPack(
        version=1,
        built_at="2026-07-23",
        topics=[
            Topic(
                id="rights-when-arrested",
                title="Your rights when you are arrested",
                category="arrest-and-police",
                jurisdiction="NG-Federal",
                summary="You may stay silent until you speak to a lawyer.",
                body_plain="arrested police remain silent lawyer informed within 24 hours",
                rights=["You may remain silent until you consult a lawyer (s.35(2))."],
                status=Status.verified,
                reviewed_by="Seed",
                citations=[Citation(source_name="1999 Constitution", locator="s.35(2)")],
            ),
            Topic(
                id="privacy-and-phone-searches",
                title="Can the police search your phone?",
                category="privacy-and-searches",
                jurisdiction="NG-Federal",
                summary="Your phone and correspondence are private and protected.",
                body_plain="police search phone privacy telephone conversations protected",
                status=Status.verified,
                reviewed_by="Seed",
                citations=[Citation(source_name="1999 Constitution", locator="s.37")],
            ),
        ],
        scenarios=[
            Scenario(
                id="being-arrested",
                trigger="I am being arrested",
                description="Steps to follow",
                jurisdiction="NG-Federal",
                steps=[ScenarioStep(text="Stay calm and do not resist.")],
                citations=[Citation(source_name="1999 Constitution", locator="s.35(2)")],
                status=Status.verified,
                reviewed_by="Seed",
            )
        ],
        directory=[DirectoryEntry(id="legal-aid", name="Legal Aid Council", entry_type="legal_aid")],
        obligations=[
            Obligation(
                id="annual-returns",
                title="File annual returns",
                category="annual-compliance",
                jurisdiction="NG-Federal",
                summary="File the required annual return.",
                applies_to=["registered companies"],
                requirements=["Prepare and deliver the return."],
                citations=[Citation(source_name="CAMA 2020", locator="ss.417-423")],
            )
        ],
        company_checklists=[
            CompanyChecklist(
                id="first-year",
                title="First year",
                description="Starter checklist",
                jurisdiction="NG-Federal",
                items=[ChecklistItem(text="Prepare the annual return.")],
                citations=[Citation(source_name="CAMA 2020", locator="ss.417-423")],
            )
        ],
    )


@pytest.fixture
def store() -> ContentStore:
    return ContentStore(_sample_pack())


@pytest.fixture
def account_service() -> AccountService:
    return AccountService(
        "sqlite+pysqlite:///:memory:",
        secret="test-secret",
        gateway=DevelopmentGateway(),
    )


@pytest.fixture
def client(
    store: ContentStore,
    account_service: AccountService,
    monkeypatch: pytest.MonkeyPatch,
) -> TestClient:
    monkeypatch.setenv("KYR_DEVELOPMENT_MODE", "1")
    return TestClient(create_app(store=store, account_service=account_service))
