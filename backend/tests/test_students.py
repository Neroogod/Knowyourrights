"""Student study tools: filters, saved cases, reading lists, and contribution.

The rule these tests protect: a student may contribute, but a student cannot
publish. Everything submitted here lands in the same review pipeline as any
other content and stays out of AI retrieval until a lawyer verifies it.
"""

import pytest
from fastapi.testclient import TestClient

from backend.schemas import CaseRelation


def auth(client: TestClient, email: str) -> dict:
    created = client.post("/v1/auth/register", json={"email": email, "password": "Str0ngPassw0rd!23"})
    client.post("/v1/auth/verify-email", json={"token": created.json()["development_verification_token"]})
    token = client.post("/v1/auth/login", json={"email": email, "password": "Str0ngPassw0rd!23"}).json()[
        "access_token"
    ]
    return {"Authorization": f"Bearer {token}"}


# ------------------------------------------------------------------- filters


def test_filters_expose_only_values_present_in_the_library(client: TestClient):
    data = client.get("/v1/students/filters").json()
    assert data["courts"] == ["Supreme Court of Nigeria"]
    assert data["years"] == [1999]
    assert "freedom-of-movement" in data["areas_of_law"]


def test_court_filter(client: TestClient):
    assert client.get("/v1/students/cases", params={"court": "Supreme Court of Nigeria"}).json()
    assert client.get("/v1/students/cases", params={"court": "Court of Appeal"}).json() == []


def test_year_filter(client: TestClient):
    assert client.get("/v1/students/cases", params={"year": 1999}).json()
    assert client.get("/v1/students/cases", params={"year": 1806}).json() == []


def test_filters_combine(client: TestClient):
    hit = client.get(
        "/v1/students/cases",
        params={"year": 1999, "court": "Supreme Court of Nigeria", "area_of_law": "freedom-of-movement"},
    ).json()
    assert len(hit) == 1
    miss = client.get("/v1/students/cases", params={"year": 1999, "court": "Court of Appeal"}).json()
    assert miss == []


# --------------------------------------------------------------- saved cases


def test_saving_requires_an_account(client: TestClient):
    assert client.put("/v1/students/saved/agbakoba-passport").status_code == 401


def test_save_and_unsave_a_case(client: TestClient):
    headers = auth(client, "student1@example.com")
    assert client.get("/v1/students/saved", headers=headers).json() == []

    assert client.put("/v1/students/saved/agbakoba-passport", headers=headers).status_code == 204
    saved = client.get("/v1/students/saved", headers=headers).json()
    assert [item["item_id"] for item in saved] == ["agbakoba-passport"]

    assert client.delete("/v1/students/saved/agbakoba-passport", headers=headers).status_code == 204
    assert client.get("/v1/students/saved", headers=headers).json() == []


def test_cannot_save_a_case_that_does_not_exist(client: TestClient):
    headers = auth(client, "student2@example.com")
    assert client.put("/v1/students/saved/no-such-case", headers=headers).status_code == 404


def test_saved_cases_are_per_user(client: TestClient):
    a = auth(client, "studenta@example.com")
    b = auth(client, "studentb@example.com")
    client.put("/v1/students/saved/agbakoba-passport", headers=a)
    assert client.get("/v1/students/saved", headers=b).json() == []


# -------------------------------------------------------------- reading lists


def test_create_and_fetch_a_reading_list(client: TestClient):
    headers = auth(client, "student3@example.com")
    response = client.put(
        "/v1/students/reading-lists/con-law",
        headers=headers,
        json={"id": "con-law", "name": "Constitutional law week 3", "case_ids": ["agbakoba-passport"]},
    )
    assert response.status_code == 204
    lists = client.get("/v1/students/reading-lists", headers=headers).json()
    assert lists[0]["payload"]["name"] == "Constitutional law week 3"
    assert lists[0]["payload"]["case_ids"] == ["agbakoba-passport"]


def test_reading_list_rejects_unknown_cases(client: TestClient):
    headers = auth(client, "student4@example.com")
    response = client.put(
        "/v1/students/reading-lists/bad",
        headers=headers,
        json={"id": "bad", "name": "Bad list", "case_ids": ["ghost-case"]},
    )
    assert response.status_code == 400
    assert "ghost-case" in response.json()["detail"]


def test_delete_a_reading_list(client: TestClient):
    headers = auth(client, "student5@example.com")
    client.put(
        "/v1/students/reading-lists/tmp", headers=headers, json={"id": "tmp", "name": "Temp", "case_ids": []}
    )
    assert client.delete("/v1/students/reading-lists/tmp", headers=headers).status_code == 204
    assert client.get("/v1/students/reading-lists", headers=headers).json() == []


# ------------------------------------------------------------ student mode


def test_law_student_mode_defaults_off_and_persists(client: TestClient):
    headers = auth(client, "student6@example.com")
    assert client.get("/v1/students/preferences", headers=headers).json()["law_student_mode"] is False

    client.put("/v1/students/preferences", headers=headers, json={"law_student_mode": True})
    # Read back through a fresh request: the setting lives server-side so it
    # survives a reinstall, which is the point of storing it at all.
    assert client.get("/v1/students/preferences", headers=headers).json()["law_student_mode"] is True


# ------------------------------------------------------------- contribution


def test_students_cannot_publish_directly(client: TestClient, account_service):
    """A reader-role student submitting is refused; nothing reaches the library."""
    headers = auth(client, "student7@example.com")
    response = client.post(
        "/v1/students/cases/agbakoba-passport/interpretations",
        headers=headers,
        json={"kind": "commentary", "body": "This case matters because " + "x" * 60},
    )
    assert response.status_code == 403


def _make_contributor(client: TestClient, account_service, email: str) -> dict:
    headers = auth(client, email)
    user_id = account_service.authenticate(headers["Authorization"].split()[1])
    with account_service.sessions.begin() as session:
        from backend.accounts import UserRoleRecord

        record = session.get(UserRoleRecord, user_id)
        record.role = "contributor"
    return headers


def test_contributed_interpretation_enters_review_not_the_library(client: TestClient, account_service):
    headers = _make_contributor(client, account_service, "contrib1@example.com")
    response = client.post(
        "/v1/students/cases/agbakoba-passport/interpretations",
        headers=headers,
        json={
            "kind": "significance",
            "body": "The decision links freedom of movement to travel documents in practice, "
            "which matters for later passport-seizure cases.",
            "citations": [{"source_name": "1999 Constitution", "locator": "s.41"}],
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "community", "student work is never verified on submission"
    assert body["payload"]["case_id"] == "agbakoba-passport"

    # And it has not appeared in the public library.
    case = client.get("/v1/students/cases/agbakoba-passport").json()
    assert all("freedom of movement to travel documents" not in i["body"] for i in case["interpretations"])


def test_interpretation_on_unknown_case_is_rejected(client: TestClient, account_service):
    headers = _make_contributor(client, account_service, "contrib2@example.com")
    response = client.post(
        "/v1/students/cases/ghost/interpretations",
        headers=headers,
        json={"kind": "ratio", "body": "y" * 60},
    )
    assert response.status_code == 404


def test_contributed_digest_enters_review(client: TestClient, account_service):
    headers = _make_contributor(client, account_service, "contrib3@example.com")
    response = client.post(
        "/v1/students/digests",
        headers=headers,
        json={
            "name": "Some Party v Another Party",
            "court": "Court of Appeal",
            "year": 2011,
            "area_of_law": "fair-hearing",
            "summary": "A short digest written in the student's own words entirely.",
            "facts": "The appellant was not given an opportunity to respond before the ruling.",
            "issues": ["Was the appellant denied a fair hearing?"],
            "holding": "The court held the process breached natural justice.",
            "ratio": "A party must be heard before a decision affecting them is made.",
            "citations": [{"source_name": "1999 Constitution", "locator": "s.36(1)"}],
        },
    )
    assert response.status_code == 201
    assert response.json()["status"] == "community"


def test_pasted_report_text_in_a_digest_is_held_back(client: TestClient, account_service):
    headers = _make_contributor(client, account_service, "contrib4@example.com")
    response = client.post(
        "/v1/students/digests",
        headers=headers,
        json={
            "name": "Copied v Pasted",
            "court": "Supreme Court of Nigeria",
            "year": 2001,
            "area_of_law": "fair-hearing",
            "summary": "Taken verbatim from the NWLR headnote for this appeal.",
            "facts": "Reproduced from the law report body text without permission.",
            "issues": ["Whether the appeal succeeds"],
            "holding": "The appeal was allowed as stated in the report.",
            "ratio": "As set out in the headnote.",
            "citations": [{"source_name": "x", "locator": "y"}],
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["status"] == "draft", "suspected report text must not go public"
    assert "possible-proprietary-copy" in body["moderation_flags"]


def test_contributor_profile_reports_their_record(client: TestClient, account_service):
    headers = _make_contributor(client, account_service, "contrib5@example.com")
    client.post(
        "/v1/students/cases/agbakoba-passport/interpretations",
        headers=headers,
        json={
            "kind": "commentary",
            "body": "A distinct piece of commentary written for this particular case study.",
            "citations": [{"source_name": "1999 Constitution", "locator": "s.41"}],
        },
    )
    profile = client.get("/v1/students/me/contributions", headers=headers).json()
    assert profile["submitted"] == 1
    assert profile["awaiting_review"] == 1
    assert profile["verified"] == 0


# --------------------------------------------------------- relationship graph


def test_case_relations_endpoint_exists_and_is_empty_until_populated(client: TestClient):
    """The citator capability ships; the edges need law reports and review."""
    assert client.get("/v1/students/cases/agbakoba-passport/related").json() == []
    assert client.get("/v1/students/cases/ghost/related").status_code == 404


def test_relations_resolve_to_cases_in_the_library(client: TestClient, store):
    case = store.get_case("agbakoba-passport")
    case.related_cases = [
        CaseRelation(relation="follows", case_id="agbakoba-passport", note="self-reference for the test"),
        CaseRelation(relation="overrules", case_id="not-in-library"),
    ]
    related = client.get("/v1/students/cases/agbakoba-passport/related").json()
    # Dangling edges are dropped rather than rendered as broken links.
    assert len(related) == 1
    assert related[0]["relation"] == "follows"
    assert related[0]["name"] == "Director SSS v Agbakoba"


def test_relation_kinds_are_constrained():
    for kind in ("cites", "follows", "distinguishes", "overrules"):
        assert CaseRelation(relation=kind, case_id="x").relation == kind
    with pytest.raises(ValueError):
        CaseRelation(relation="mentions", case_id="x")


def test_relations_default_to_draft():
    # Asserting that one case overrules another is a legal claim; it is reviewed
    # like any other, so it cannot default to verified.
    assert CaseRelation(relation="overrules", case_id="x").status.value == "draft"
