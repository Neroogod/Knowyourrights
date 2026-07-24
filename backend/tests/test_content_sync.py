import base64
import hashlib

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from backend.content_sync import ContentSigner, canonical_json, signed_pack


def signer() -> ContentSigner:
    raw = hashlib.sha256(b"test-content-signing").digest()
    return ContentSigner(Ed25519PrivateKey.from_private_bytes(raw), "test-key")


def verify(envelope: dict, public_key: bytes) -> None:
    signature = base64.urlsafe_b64decode(envelope["signature"] + "=" * (-len(envelope["signature"]) % 4))
    payload = {key: value for key, value in envelope.items() if key != "signature"}
    Ed25519PrivateKey.from_private_bytes(public_key).public_key().verify(signature, canonical_json(payload))


def test_signed_rights_pack_is_layered_and_verifiable(store) -> None:
    private = hashlib.sha256(b"test-content-signing").digest()
    envelope, etag = signed_pack(store._pack, "rights", "NG-Federal", 0, signer())
    verify(envelope, private)
    assert envelope["layer"] == "rights"
    assert envelope["upserts"]["topics"]
    assert "cases" not in envelope["upserts"]
    assert etag.startswith('"rights-NG-Federal-')
    checksum = hashlib.sha256(canonical_json(envelope["upserts"])).hexdigest()
    assert envelope["checksum"] == checksum


def test_content_pack_endpoint_supports_etag_and_since(client) -> None:
    first = client.get("/v1/content-packs/students")
    assert first.status_code == 200
    assert first.json()["upserts"]["cases"]
    etag = first.headers["etag"]
    assert client.get("/v1/content-packs/students", headers={"If-None-Match": etag}).status_code == 304
    version = first.json()["content_version"]
    assert client.get(f"/v1/content-packs/students?since={version}").status_code == 304
