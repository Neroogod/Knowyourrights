"""Trust and editorial operations: the pipeline behind the Verified badge.

These tests assert the guarantees the product's credibility rests on: only a
reviewer can verify, nobody reviews their own work, suspected proprietary copies
cannot be published, every decision is auditable, and content past its review
date stops being answerable.
"""

from datetime import date, timedelta

import pytest
from fastapi.testclient import TestClient

from backend.accounts import AccountService
from backend.review import (
    FLAG_THRESHOLD,
    ReviewError,
    ReviewService,
    screen_submission,
)
from backend.schemas import Status, Topic, is_retrievable, is_stale

# --------------------------------------------------------------------- helpers


def make_user(accounts: AccountService, email: str, role: str = "reader") -> str:
    verification_token = accounts.register(email, "Str0ngPassw0rd!23")
    accounts.verify_email(verification_token)
    user_id = accounts.authenticate(accounts.login(email, "Str0ngPassw0rd!23"))
    if role != "reader":
        with accounts.sessions.begin() as session:
            from backend.accounts import UserRoleRecord

            record = session.get(UserRoleRecord, user_id)
            if record is None:
                session.add(UserRoleRecord(user_id=user_id, role=role, updated_at=accounts._now()))
            else:
                record.role = role
    return user_id


@pytest.fixture
def reviews(account_service: AccountService) -> ReviewService:
    return ReviewService(account_service)


VALID_PAYLOAD = {
    "summary": "A tenant may not be evicted without a court order.",
    "citations": [{"source_name": "1999 Constitution", "locator": "s.36(1)"}],
}


# ------------------------------------------------------------------ moderation


def test_submission_without_citation_is_flagged():
    result = screen_submission({"summary": "Something asserted with no source."})
    assert "missing-citation" in result.flags


def test_pasted_law_report_text_is_caught_and_blocked():
    result = screen_submission(
        {
            "summary": "Per the headnote in the NWLR report, the appeal succeeded.",
            "citations": [{"source_name": "x", "locator": "y"}],
        }
    )
    assert "possible-proprietary-copy" in result.flags
    assert result.blocked, "licensed report text must be held back, not published"


def test_near_duplicate_submission_is_flagged():
    text = "A tenant may not be evicted without a court order issued by a court."
    result = screen_submission(
        {"summary": text, "citations": [{"source_name": "x", "locator": "y"}]},
        existing_texts=[text],
    )
    assert "possible-duplicate" in result.flags


def test_clean_submission_has_no_flags():
    assert screen_submission(VALID_PAYLOAD).flags == ()


# ---------------------------------------------------------------- contribution


def test_reader_cannot_contribute(reviews, account_service):
    reader = make_user(account_service, "reader@example.com")
    with pytest.raises(ReviewError):
        reviews.submit(reader, "topic", "A topic", VALID_PAYLOAD)


def test_clean_contribution_enters_community_not_verified(reviews, account_service):
    author = make_user(account_service, "author@example.com", "contributor")
    item = reviews.submit(author, "topic", "Eviction needs a court order", VALID_PAYLOAD)
    # Community content is visible but must never be treated as authoritative.
    assert item["status"] == "community"
    assert item["moderation_flags"] == []


def test_flagged_contribution_is_held_as_draft(reviews, account_service):
    author = make_user(account_service, "author2@example.com", "contributor")
    item = reviews.submit(author, "topic", "Uncited claim", {"summary": "No source at all."})
    assert item["status"] == "draft"
    assert "missing-citation" in item["moderation_flags"]


def test_submission_rate_limit(reviews, account_service):
    author = make_user(account_service, "spammer@example.com", "contributor")
    for i in range(10):
        reviews.submit(author, "topic", f"Item {i}", {"summary": f"Distinct body {i}",
                                                      "citations": [{"source_name": "s", "locator": "l"}]})
    with pytest.raises(ReviewError, match="rate limit"):
        reviews.submit(author, "topic", "One too many", VALID_PAYLOAD)


# --------------------------------------------------------------------- review


def test_contributor_cannot_verify_their_own_work(reviews, account_service):
    author = make_user(account_service, "selfreview@example.com", "contributor")
    item = reviews.submit(author, "topic", "Mine", VALID_PAYLOAD)
    with pytest.raises(ReviewError):
        reviews.decide(author, item["id"], "approve")


def test_reviewer_cannot_approve_their_own_submission(reviews, account_service):
    reviewer = make_user(account_service, "double@example.com", "reviewer")
    item = reviews.submit(reviewer, "topic", "Mine too", VALID_PAYLOAD)
    with pytest.raises(ReviewError, match="own submission"):
        reviews.decide(reviewer, item["id"], "approve")


def test_reviewer_approval_verifies_content(reviews, account_service):
    author = make_user(account_service, "a3@example.com", "contributor")
    reviewer = make_user(account_service, "r3@example.com", "reviewer")
    item = reviews.submit(author, "topic", "Good work", VALID_PAYLOAD)
    decided = reviews.decide(reviewer, item["id"], "approve", "Checked against s.36.")
    assert decided["status"] == "verified"


def test_rejection_and_changes_require_notes(reviews, account_service):
    author = make_user(account_service, "a4@example.com", "contributor")
    reviewer = make_user(account_service, "r4@example.com", "reviewer")
    item = reviews.submit(author, "topic", "Needs work", VALID_PAYLOAD)
    with pytest.raises(ReviewError, match="notes are required"):
        reviews.decide(reviewer, item["id"], "changes")


def test_changes_send_it_back_to_draft_with_notes(reviews, account_service):
    author = make_user(account_service, "a5@example.com", "contributor")
    reviewer = make_user(account_service, "r5@example.com", "reviewer")
    item = reviews.submit(author, "topic", "Nearly", VALID_PAYLOAD)
    reviews.decide(reviewer, item["id"], "changes", "Cite the subsection, not the section.")
    history = reviews.reviews_for(item["id"])
    assert history[0]["decision"] == "changes"
    assert "subsection" in history[0]["notes"]


def test_rejected_content_is_archived_not_deleted(reviews, account_service):
    author = make_user(account_service, "a6@example.com", "contributor")
    reviewer = make_user(account_service, "r6@example.com", "reviewer")
    item = reviews.submit(author, "topic", "Wrong", VALID_PAYLOAD)
    decided = reviews.decide(reviewer, item["id"], "reject", "Not supported by the cited section.")
    assert decided["status"] == "archived", "audit trail requires archive, never delete"


def test_proprietary_flag_blocks_verification(reviews, account_service):
    author = make_user(account_service, "a7@example.com", "contributor")
    reviewer = make_user(account_service, "r7@example.com", "reviewer")
    item = reviews.submit(
        author,
        "case",
        "Copied digest",
        {"summary": "From the NWLR headnote.", "citations": [{"source_name": "s", "locator": "l"}]},
    )
    with pytest.raises(ReviewError, match="proprietary"):
        reviews.decide(reviewer, item["id"], "approve")


def test_queue_shows_community_items_to_reviewers_only(reviews, account_service):
    author = make_user(account_service, "a8@example.com", "contributor")
    reviewer = make_user(account_service, "r8@example.com", "reviewer")
    reviews.submit(author, "topic", "Queued", VALID_PAYLOAD)
    assert len(reviews.queue(reviewer)) == 1
    with pytest.raises(ReviewError):
        reviews.queue(author)


# --------------------------------------------------------------- error reports


def test_anyone_can_report_an_error_without_an_account(reviews):
    report = reviews.report_error("topic", "rights-when-arrested", "The time limit looks wrong.")
    assert report["status"] == "open"
    assert report["open_reports"] == 1


def test_reports_flag_a_record_once_the_threshold_is_reached(reviews):
    for i in range(FLAG_THRESHOLD):
        report = reviews.report_error("topic", "same-topic", f"Problem {i}")
    assert report["flagged_for_review"] is True


def test_triage_queue_and_resolution(reviews, account_service):
    reviewer = make_user(account_service, "r9@example.com", "reviewer")
    report = reviews.report_error("topic", "t1", "Wrong citation.")
    assert len(reviews.error_queue(reviewer)) == 1
    resolved = reviews.resolve_error(reviewer, report["id"], "resolved", "Citation corrected.")
    assert resolved["status"] == "resolved"
    assert reviews.error_queue(reviewer) == []


def test_readers_cannot_see_the_triage_queue(reviews, account_service):
    reader = make_user(account_service, "nosy@example.com")
    with pytest.raises(ReviewError):
        reviews.error_queue(reader)


def test_flagged_targets_lists_records_needing_re_review(reviews, account_service):
    reviewer = make_user(account_service, "r10@example.com", "reviewer")
    for i in range(FLAG_THRESHOLD):
        reviews.report_error("topic", "bad-topic", f"Issue {i}")
    flagged = reviews.flagged_targets(reviewer)
    assert flagged[0]["target_id"] == "bad-topic"
    assert flagged[0]["open_reports"] >= FLAG_THRESHOLD


# -------------------------------------------------------------------- audit


def test_every_decision_is_audited(reviews, account_service):
    author = make_user(account_service, "a11@example.com", "contributor")
    reviewer = make_user(account_service, "r11@example.com", "reviewer")
    admin = make_user(account_service, "admin11@example.com", "administrator")
    item = reviews.submit(author, "topic", "Audited", VALID_PAYLOAD)
    reviews.decide(reviewer, item["id"], "approve", "Fine.")

    trail = reviews.audit_trail(admin, target_id=item["id"])
    actions = {entry["action"] for entry in trail}
    assert "contribution.submitted" in actions
    assert "contribution.approve" in actions
    approved = next(e for e in trail if e["action"] == "contribution.approve")
    assert approved["before"]["status"] == "community"
    assert approved["after"]["status"] == "verified"
    assert approved["actor_user_id"] == reviewer


def test_audit_log_is_administrator_only(reviews, account_service):
    reviewer = make_user(account_service, "r12@example.com", "reviewer")
    with pytest.raises(ReviewError):
        reviews.audit_trail(reviewer)


def test_audit_log_has_no_write_or_delete_api():
    # The trail is only trustworthy if code cannot rewrite it.
    assert not any(
        hasattr(ReviewService, name)
        for name in ("update_audit", "delete_audit", "purge_audit", "edit_audit")
    )


# ----------------------------------------------------------------- staleness


def test_is_stale_only_when_the_due_date_has_passed():
    today = date(2026, 7, 23)
    assert is_stale("2026-07-22", today) is True
    assert is_stale("2026-07-23", today) is False
    assert is_stale("2027-01-01", today) is False
    assert is_stale(None, today) is False
    assert is_stale("not-a-date", today) is False


def test_retrievability_requires_verified_and_fresh():
    today = date(2026, 7, 23)
    assert is_retrievable("verified", None, today) is True
    assert is_retrievable("verified", "2026-07-01", today) is False
    assert is_retrievable("community", None, today) is False


def test_stale_topic_is_dropped_from_retrieval():
    from backend.rag.answerer import build_documents

    fresh = Topic(
        id="fresh", title="Fresh", category="c", jurisdiction="NG-Federal",
        summary="s", body_plain="b", status=Status.verified, reviewed_by="L",
        citations=[{"source_name": "1999 Constitution", "locator": "s.35"}],
        review_due_at=(date.today() + timedelta(days=30)).isoformat(),
    )
    stale = Topic(
        id="stale", title="Stale", category="c", jurisdiction="NG-Federal",
        summary="s", body_plain="b", status=Status.verified, reviewed_by="L",
        citations=[{"source_name": "1999 Constitution", "locator": "s.35"}],
        review_due_at=(date.today() - timedelta(days=1)).isoformat(),
    )
    ids = {d.topic_id for d in build_documents([fresh, stale])}
    assert ids == {"fresh"}, "content past its review date must leave AI retrieval"


def test_stale_content_is_listed_for_reviewers(reviews, account_service, store):
    reviewer = make_user(account_service, "r13@example.com", "reviewer")
    pack = store._pack
    pack.topics[0].review_due_at = (date.today() - timedelta(days=5)).isoformat()
    stale = reviews.stale_content(reviewer, pack)
    assert any(item["target_id"] == pack.topics[0].id for item in stale)


# ----------------------------------------------------------------------- API


def _register(client: TestClient, email: str) -> str:
    created = client.post("/v1/auth/register", json={"email": email, "password": "Str0ngPassw0rd!23"})
    client.post("/v1/auth/verify-email",
                json={"token": created.json()["development_verification_token"]})
    token = client.post("/v1/auth/login", json={"email": email, "password": "Str0ngPassw0rd!23"})
    return token.json()["access_token"]


def test_error_report_endpoint_accepts_anonymous_reports(client: TestClient):
    response = client.post(
        "/v1/error-reports",
        json={"target_type": "topic", "target_id": "rights-when-arrested",
              "message": "The 24-hour rule looks wrong."},
    )
    assert response.status_code == 201
    assert response.json()["status"] == "open"


def test_review_queue_requires_a_reviewer(client: TestClient):
    token = _register(client, "plainreader@example.com")
    response = client.get("/v1/review/queue", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 403


def test_contribution_endpoint_rejects_readers(client: TestClient):
    token = _register(client, "reader2@example.com")
    response = client.post(
        "/v1/contributions",
        headers={"Authorization": f"Bearer {token}"},
        json={"content_type": "topic", "title": "Attempt", "payload": VALID_PAYLOAD},
    )
    assert response.status_code == 403


def test_audit_log_endpoint_requires_administrator(client: TestClient):
    token = _register(client, "reader3@example.com")
    response = client.get("/v1/admin/audit-log", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 403
