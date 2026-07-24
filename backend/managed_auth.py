"""Supabase Auth JWT verification for the FastAPI resource server."""

import os
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import jwt

from backend.accounts import AccountError


@dataclass(frozen=True)
class AuthIdentity:
    user_id: str
    email: str
    session_id: str | None
    role: str
    authenticated_at: datetime

    @property
    def recently_authenticated(self) -> bool:
        return (datetime.now(UTC) - self.authenticated_at).total_seconds() <= 600


class SupabaseTokenVerifier:
    """Verify asymmetric Supabase access tokens through the project's JWKS."""

    def __init__(self, project_url: str | None = None) -> None:
        self.project_url = (project_url or os.getenv("SUPABASE_URL", "")).rstrip("/")
        self.enabled = bool(self.project_url)
        self.issuer = f"{self.project_url}/auth/v1" if self.enabled else ""
        self._jwks = (
            jwt.PyJWKClient(f"{self.issuer}/.well-known/jwks.json", cache_keys=True)
            if self.enabled
            else None
        )

    def verify(self, token: str) -> AuthIdentity:
        if not self.enabled or self._jwks is None:
            raise AccountError("managed authentication is not configured")
        try:
            signing_key = self._jwks.get_signing_key_from_jwt(token)
            claims: dict[str, Any] = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256", "ES256"],
                audience="authenticated",
                issuer=self.issuer,
            )
            metadata = claims.get("app_metadata") or {}
            auth_time = int(claims.get("auth_time") or claims["iat"])
            return AuthIdentity(
                user_id=str(claims["sub"]),
                email=str(claims.get("email") or ""),
                session_id=str(claims["session_id"]) if claims.get("session_id") else None,
                role=str(metadata.get("app_role") or "reader"),
                authenticated_at=datetime.fromtimestamp(auth_time, UTC),
            )
        except (KeyError, TypeError, ValueError, jwt.PyJWTError) as error:
            raise AccountError("invalid access token") from error
