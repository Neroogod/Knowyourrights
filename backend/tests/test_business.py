"""Company applicability: show a business only the obligations that bind it.

The rule these tests protect is a safety rule as much as a UX one: when in doubt,
show the obligation. A business that has not described itself, or a duty with no
stated limits, must never have a real obligation hidden from it.
"""

from fastapi.testclient import TestClient

from backend.schemas import Applicability, EntityProfile, Obligation, obligation_applies


def _obligation(oid: str, applicability: Applicability | None) -> Obligation:
    return Obligation(
        id=oid,
        title=oid,
        category="c",
        jurisdiction="NG-Federal",
        summary="s",
        applies_to=["x"],
        applicability=applicability,
        requirements=["do the thing"],
        citations=[{"source_name": "CAMA 2020", "locator": "s.1"}],
    )


# --------------------------------------------------------------- pure matcher


def test_no_limits_binds_everyone():
    assert obligation_applies(None, EntityProfile()) is True
    assert obligation_applies(Applicability(), EntityProfile(entity_type="ngo")) is True


def test_entity_type_limit():
    ltd_only = Applicability(entity_types=["ltd", "plc"])
    assert obligation_applies(ltd_only, EntityProfile(entity_type="ltd")) is True
    assert obligation_applies(ltd_only, EntityProfile(entity_type="ngo")) is False


def test_staff_band():
    big = Applicability(staff_min=50)
    assert obligation_applies(big, EntityProfile(staff_count=80)) is True
    assert obligation_applies(big, EntityProfile(staff_count=12)) is False


def test_unknown_profile_field_never_hides_an_obligation():
    # A business that has not said how many staff it has still sees staff-scoped
    # duties. Hiding a real obligation is the more dangerous error.
    staff_scoped = Applicability(staff_min=50)
    assert obligation_applies(staff_scoped, EntityProfile(entity_type="ltd")) is True


def test_state_and_sector_and_turnover():
    lagos_retail = Applicability(states=["Lagos"], sectors=["retail"], turnover_bands=["small"])
    match = EntityProfile(state="Lagos", sector="retail", turnover_band="small")
    assert obligation_applies(lagos_retail, match) is True
    assert obligation_applies(lagos_retail, EntityProfile(state="Kano", sector="retail")) is False


# ------------------------------------------------------------------- endpoint


def test_applicable_returns_all_for_an_empty_profile(client: TestClient):
    response = client.post("/v1/business/applicable", json={})
    assert response.status_code == 200
    data = response.json()
    assert len(data["obligations"]) == 1  # the sample pack's one obligation


def test_applicable_filters_by_entity_type(client: TestClient, store):
    # Constrain the sample obligation to companies only, then ask as an NGO.
    store._obligations["annual-returns"].applicability = Applicability(entity_types=["ltd", "plc"])
    assert client.post("/v1/business/applicable", json={"entity_type": "ngo"}).json()["obligations"] == []
    assert client.post("/v1/business/applicable", json={"entity_type": "ltd"}).json()["obligations"]


def test_applicable_does_not_persist_the_profile(client: TestClient):
    # The profile is a filter, not an account: two requests are independent.
    client.post("/v1/business/applicable", json={"entity_type": "ngo"})
    everyone = client.post("/v1/business/applicable", json={}).json()
    assert len(everyone["obligations"]) == 1


def test_real_pack_obligations_carry_structured_applicability():
    # The shipped CAMA obligations must have machine-filterable metadata, not just
    # the human-readable applies_to list.
    from pathlib import Path

    from backend.schemas import ContentPack

    pack_path = Path(__file__).resolve().parents[2] / "data" / "content_pack.json"
    if not pack_path.exists():
        return
    import json

    pack = ContentPack.model_validate(json.loads(pack_path.read_text()))
    enriched = [o for o in pack.obligations if o.applicability is not None]
    assert enriched, "shipped obligations should carry structured applicability"
    assert all(o.frequency for o in enriched), "every enriched obligation states a frequency"


# ----------------------------------------------------------------- regulators


def test_regulators_endpoint_lists_the_bodies_with_official_links(client: TestClient, store):
    from backend.schemas import DirectoryEntry

    store._directory.append(
        DirectoryEntry(id="cac", name="Corporate Affairs Commission (CAC)",
                       entry_type="regulator", state="Federal", url="https://www.cac.gov.ng/")
    )
    regulators = client.get("/v1/company/regulators").json()
    assert any(r["id"] == "cac" for r in regulators)
    assert all(r["entry_type"] == "regulator" for r in regulators)
    # We link to regulators; we do not invent their phone numbers.
    assert all(r["url"] for r in regulators)


def test_shipped_regulator_directory_uses_official_gov_domains():
    from pathlib import Path

    from backend.schemas import ContentPack

    pack_path = Path(__file__).resolve().parents[2] / "data" / "content_pack.json"
    if not pack_path.exists():
        return
    import json

    pack = ContentPack.model_validate(json.loads(pack_path.read_text()))
    regulators = [e for e in pack.directory if e.entry_type == "regulator"]
    expected = {"cac", "firs", "ndpc", "pencom", "nsitf", "itf"}
    assert expected.issubset({r.id for r in regulators})
    for regulator in regulators:
        assert regulator.url and "gov.ng" in regulator.url, f"{regulator.id} should link to a .gov.ng site"
        # No fabricated contact numbers.
        assert regulator.phone is None
