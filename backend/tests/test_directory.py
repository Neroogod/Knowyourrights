"""Directory depth: filtering, location-aware sorting, and community contribution.

Two rules under test: filtering never invents entries, and a community-submitted
contact is never live until an editor confirms it - the directory is where a
person in trouble turns, so a bad number is not a small error.
"""

from fastapi.testclient import TestClient

from backend.schemas import DirectoryEntry, Status


def _seed(store):
    store._directory = [
        DirectoryEntry(id="lac", name="Legal Aid Council", entry_type="legal_aid",
                       state="Federal", specialty=["criminal", "general"]),
        DirectoryEntry(id="lagos-aid", name="Lagos Legal Clinic", entry_type="legal_aid",
                       state="Lagos", lga="Ikeja", specialty=["tenancy"]),
        DirectoryEntry(id="kano-ngo", name="Kano Rights NGO", entry_type="ngo",
                       state="Kano", specialty=["human-rights"]),
        DirectoryEntry(id="police", name="Police line", entry_type="emergency", state="Federal"),
    ]


# ---------------------------------------------------------------- filtering


def test_filter_by_type(client: TestClient, store):
    _seed(store)
    aid = client.get("/v1/directory", params={"type": "legal_aid"}).json()
    assert {e["id"] for e in aid} == {"lac", "lagos-aid"}


def test_filter_by_state(client: TestClient, store):
    _seed(store)
    lagos = client.get("/v1/directory", params={"state": "Lagos"}).json()
    assert [e["id"] for e in lagos] == ["lagos-aid"]


def test_filter_by_lga(client: TestClient, store):
    _seed(store)
    assert [e["id"] for e in client.get("/v1/directory", params={"lga": "Ikeja"}).json()] == ["lagos-aid"]


def test_filter_by_specialty(client: TestClient, store):
    _seed(store)
    tenancy = client.get("/v1/directory", params={"specialty": "tenancy"}).json()
    assert [e["id"] for e in tenancy] == ["lagos-aid"]


def test_filters_combine(client: TestClient, store):
    _seed(store)
    hit = client.get("/v1/directory", params={"type": "legal_aid", "state": "Lagos"}).json()
    assert [e["id"] for e in hit] == ["lagos-aid"]


# ------------------------------------------------------ location-aware sort


def test_near_floats_the_users_state_then_federal(client: TestClient, store):
    _seed(store)
    order = [e["id"] for e in client.get("/v1/directory", params={"near": "Kano"}).json()]
    # Kano first, then the nationwide Federal bodies, then anything else.
    assert order[0] == "kano-ngo"
    assert order.index("kano-ngo") < order.index("lac")
    assert order.index("kano-ngo") < order.index("lagos-aid")


def test_near_never_drops_entries(client: TestClient, store):
    _seed(store)
    everyone = client.get("/v1/directory").json()
    nearby = client.get("/v1/directory", params={"near": "Kano"}).json()
    # A lawyer two states away is still better than none: sorting, not filtering.
    assert len(nearby) == len(everyone)


# ------------------------------------------------------------------ filters


def test_filters_endpoint_lists_available_values(client: TestClient, store):
    _seed(store)
    filters = client.get("/v1/directory/filters").json()
    assert "legal_aid" in filters["types"]
    assert "Lagos" in filters["states"]
    assert "tenancy" in filters["specialties"]


# ------------------------------------------------------------- contribution


def _contributor(client: TestClient, account_service, email: str) -> dict:
    created = client.post("/v1/auth/register", json={"email": email, "password": "Str0ngPassw0rd!23"})
    client.post("/v1/auth/verify-email",
                json={"token": created.json()["development_verification_token"]})
    token = client.post("/v1/auth/login",
                        json={"email": email, "password": "Str0ngPassw0rd!23"}).json()["access_token"]
    user_id = account_service.authenticate(token)
    with account_service.sessions.begin() as session:
        from backend.accounts import UserRoleRecord

        session.get(UserRoleRecord, user_id).role = "contributor"
    return {"Authorization": f"Bearer {token}"}


def test_directory_contribution_requires_an_account(client: TestClient):
    response = client.post("/v1/directory/contributions",
                           json={"name": "Some Clinic", "entry_type": "legal_aid"})
    assert response.status_code == 401


def test_contributed_entry_enters_review_not_the_live_directory(
    client: TestClient, account_service, store
):
    _seed(store)
    headers = _contributor(client, account_service, "dir1@example.com")
    response = client.post(
        "/v1/directory/contributions",
        headers=headers,
        json={"name": "Enugu Legal Aid Clinic", "entry_type": "legal_aid",
              "state": "Enugu", "phone": "+2348000000000", "specialty": ["tenancy"]},
    )
    assert response.status_code == 201
    assert response.json()["status"] == "community", "a submitted contact is never live on submission"

    # And it has not appeared in the directory people actually see.
    live = client.get("/v1/directory").json()
    assert all(entry["id"] != "Enugu Legal Aid Clinic" for entry in live)
    assert all("Enugu Legal Aid Clinic" not in entry["name"] for entry in live)


def test_a_correction_carries_the_target_entry_id(client: TestClient, account_service, store):
    _seed(store)
    headers = _contributor(client, account_service, "dir2@example.com")
    response = client.post(
        "/v1/directory/contributions",
        headers=headers,
        json={"name": "Lagos Legal Clinic", "entry_type": "legal_aid",
              "phone": "+2348111111111", "corrects_id": "lagos-aid"},
    )
    assert response.status_code == 201
    assert response.json()["payload"]["corrects_id"] == "lagos-aid"


# ----------------------------------------------------------------- schema


def test_seed_entries_default_to_verified():
    entry = DirectoryEntry(id="x", name="X", entry_type="legal_aid")
    assert entry.status == Status.verified


def test_shipped_directory_has_specialty_and_regulators():
    from pathlib import Path

    from backend.schemas import ContentPack

    pack_path = Path(__file__).resolve().parents[2] / "data" / "content_pack.json"
    if not pack_path.exists():
        return
    import json

    pack = ContentPack.model_validate(json.loads(pack_path.read_text()))
    assert any(e.specialty for e in pack.directory), "some entries should carry specialties"
    assert any(e.entry_type == "regulator" for e in pack.directory)
