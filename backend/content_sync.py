"""Signed, versioned, layer-specific content packs for offline clients."""

from __future__ import annotations

import base64
import hashlib
import json
import os
from dataclasses import dataclass

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from backend.schemas import ContentPack

LAYERS = {"rights", "students", "company"}


def canonical_json(value: dict) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


@dataclass(frozen=True)
class ContentSigner:
    private_key: Ed25519PrivateKey
    key_id: str

    @classmethod
    def from_environment(cls) -> ContentSigner:
        encoded = os.getenv("KYR_CONTENT_SIGNING_PRIVATE_KEY")
        if encoded:
            raw = base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4))
        else:
            secret = os.getenv("KYR_APP_SECRET")
            if not secret:
                if os.getenv("KYR_DEVELOPMENT_MODE") == "1":
                    secret = "development-only-content-signing-key"
                else:
                    raise RuntimeError(
                        "KYR_CONTENT_SIGNING_PRIVATE_KEY or KYR_APP_SECRET is required"
                    )
            raw = hashlib.sha256(f"content-signing:{secret}".encode()).digest()
        private_key = Ed25519PrivateKey.from_private_bytes(raw)
        public = private_key.public_key().public_bytes_raw()
        return cls(private_key, hashlib.sha256(public).hexdigest()[:16])

    @property
    def public_key(self) -> str:
        return base64.urlsafe_b64encode(
            self.private_key.public_key().public_bytes_raw()
        ).decode().rstrip("=")

    def sign(self, payload: dict) -> str:
        return base64.urlsafe_b64encode(
            self.private_key.sign(canonical_json(payload))
        ).decode().rstrip("=")


def layer_data(pack: ContentPack, layer: str, jurisdiction: str) -> dict:
    if layer not in LAYERS:
        raise ValueError("unsupported content layer")

    def allowed(item: object) -> bool:
        item_jurisdiction = getattr(item, "jurisdiction", "general")
        return item_jurisdiction in {jurisdiction, "NG-Federal", "general"}

    if layer == "rights":
        return {
            "topics": [item.model_dump(mode="json") for item in pack.topics if allowed(item)],
            "scenarios": [
                item.model_dump(mode="json") for item in pack.scenarios if allowed(item)
            ],
            "directory": [
                item.model_dump(mode="json")
                for item in pack.directory
                if item.cached_offline
                and (item.state is None or jurisdiction in {"NG-Federal", f"NG-{item.state}"})
            ],
        }
    if layer == "students":
        return {"cases": [item.model_dump(mode="json") for item in pack.cases if allowed(item)]}
    return {
        "obligations": [
            item.model_dump(mode="json") for item in pack.obligations if allowed(item)
        ],
        "company_checklists": [
            item.model_dump(mode="json")
            for item in pack.company_checklists
            if allowed(item)
        ],
    }


def signed_pack(
    pack: ContentPack,
    layer: str,
    jurisdiction: str,
    since: int,
    signer: ContentSigner,
) -> tuple[dict, str]:
    data = layer_data(pack, layer, jurisdiction)
    checksum = hashlib.sha256(canonical_json(data)).hexdigest()
    payload = {
        "schema_version": 1,
        "content_version": pack.version,
        "base_version": since,
        "layer": layer,
        "jurisdiction": jurisdiction,
        "built_at": pack.built_at,
        "is_delta": since > 0,
        "upserts": data if since < pack.version else {},
        "removed": {},
        "checksum": checksum,
        "key_id": signer.key_id,
    }
    envelope = {**payload, "signature": signer.sign(payload)}
    etag = f'"{layer}-{jurisdiction}-{pack.version}-{checksum[:16]}"'
    return envelope, etag
