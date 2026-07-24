"""Persistent account, consent, and custody-alert service."""

import base64
import hashlib
import json
import os
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import (
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    create_engine,
    delete,
    func,
    inspect,
    select,
    update,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker
from sqlalchemy.pool import StaticPool

from backend.delivery import DeliveryError, DeliveryGateway, DevelopmentGateway

DEFAULT_DATABASE_URL = f"sqlite:///{Path(__file__).resolve().parents[1] / 'data' / 'accounts.db'}"
TOKEN_TTL = timedelta(minutes=60)
ACCESS_TTL = timedelta(hours=1)
GENERIC_REGISTER_MESSAGE = "If this address can be registered, a verification email has been sent."


def _as_utc(value: datetime) -> datetime:
    """Treat a naive datetime as UTC so stored and incoming times compare safely."""
    return value if value.tzinfo else value.replace(tzinfo=UTC)


class Base(DeclarativeBase):
    pass


class UserRecord(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    email_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ProfileRecord(Base):
    __tablename__ = "profiles"

    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), primary_key=True)
    full_name: Mapped[str] = mapped_column(String(120))
    phone_encrypted: Mapped[str] = mapped_column(String(500))
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ContactRecord(Base):
    __tablename__ = "emergency_contacts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    phone_encrypted: Mapped[str] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class ContactChannelRecord(Base):
    __tablename__ = "contact_channels"

    contact_id: Mapped[str] = mapped_column(ForeignKey("emergency_contacts.id"), primary_key=True)
    email_encrypted: Mapped[str | None] = mapped_column(String(500))
    push_token_encrypted: Mapped[str | None] = mapped_column(String(1000))
    whatsapp_enabled: Mapped[bool] = mapped_column(default=False)
    email_enabled: Mapped[bool] = mapped_column(default=False)
    push_enabled: Mapped[bool] = mapped_column(default=False)


class VerificationRecord(Base):
    __tablename__ = "verification_tokens"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    subject_id: Mapped[str] = mapped_column(String(36), index=True)
    purpose: Mapped[str] = mapped_column(String(30), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AlertRecord(Base):
    __tablename__ = "custody_alerts"
    __table_args__ = (UniqueConstraint("user_id", "idempotency_key"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    contact_id: Mapped[str] = mapped_column(ForeignKey("emergency_contacts.id"))
    idempotency_key: Mapped[str] = mapped_column(String(100))
    latitude_encrypted: Mapped[str | None] = mapped_column(String(500))
    longitude_encrypted: Mapped[str | None] = mapped_column(String(500))
    accuracy: Mapped[float | None] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String(20))
    provider_message_id: Mapped[str | None] = mapped_column(String(120))
    triggered_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class AlertDeliveryRecord(Base):
    __tablename__ = "alert_deliveries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    alert_id: Mapped[str] = mapped_column(ForeignKey("custody_alerts.id"), index=True)
    channel: Mapped[str] = mapped_column(String(30), default="gateway_sms")
    status: Mapped[str] = mapped_column(String(20), default="queued")
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    provider_message_id: Mapped[str | None] = mapped_column(String(120), index=True)
    last_error: Mapped[str | None] = mapped_column(String(255))
    next_retry_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class AlertMetadataRecord(Base):
    __tablename__ = "alert_metadata"

    alert_id: Mapped[str] = mapped_column(ForeignKey("custody_alerts.id"), primary_key=True)
    public_token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    public_token_encrypted: Mapped[str] = mapped_column(String(500))
    station_name_encrypted: Mapped[str | None] = mapped_column(String(500))
    is_test: Mapped[bool] = mapped_column(default=False)


class UserRoleRecord(Base):
    __tablename__ = "user_roles"

    user_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    role: Mapped[str] = mapped_column(String(20), default="reader")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class DeviceSessionRecord(Base):
    __tablename__ = "device_sessions"

    session_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    device_id_hash: Mapped[str] = mapped_column(String(64), index=True)
    device_name: Mapped[str] = mapped_column(String(120))
    first_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class AbuseEventRecord(Base):
    __tablename__ = "abuse_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    key_hash: Mapped[str] = mapped_column(String(64), index=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class WebhookEventRecord(Base):
    __tablename__ = "webhook_events"

    event_id_hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    received_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class CheckInRecord(Base):
    __tablename__ = "check_ins"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(String(36), index=True)
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    status: Mapped[str] = mapped_column(String(20), index=True)
    station_name_encrypted: Mapped[str | None] = mapped_column(String(500))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class UserSyncRecord(Base):
    __tablename__ = "user_sync_items"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)
    kind: Mapped[str] = mapped_column(String(20), index=True)
    item_id: Mapped[str] = mapped_column(String(160))
    payload_json: Mapped[str] = mapped_column(String(12000))
    deleted: Mapped[bool] = mapped_column(default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    __table_args__ = (UniqueConstraint("user_id", "kind", "item_id", name="uq_user_sync_item"),)


class AIAnswerCacheRecord(Base):
    __tablename__ = "ai_answer_cache"
    cache_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    response_json: Mapped[str] = mapped_column(String(24000))
    content_version: Mapped[int] = mapped_column(Integer)
    model_key: Mapped[str] = mapped_column(String(255))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    hits: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class AIUsageRecord(Base):
    __tablename__ = "ai_usage_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    privacy_id: Mapped[str] = mapped_column(String(64), index=True)
    user_id: Mapped[str | None] = mapped_column(String(36), index=True)
    corpus: Mapped[str] = mapped_column(String(24), index=True)
    jurisdiction: Mapped[str] = mapped_column(String(80), index=True)
    model_key: Mapped[str] = mapped_column(String(255))
    latency_ms: Mapped[int] = mapped_column(Integer)
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    estimated_cost_usd: Mapped[float] = mapped_column(Float, default=0.0)
    cache_hit: Mapped[bool] = mapped_column(default=False)
    refused: Mapped[bool] = mapped_column(default=False)
    sampled_for_review: Mapped[bool] = mapped_column(default=False, index=True)
    response_json: Mapped[str | None] = mapped_column(String(24000))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class SubscriptionRecord(Base):
    """A subject's paid plan. Absence of an active row means the free plan."""

    __tablename__ = "subscriptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    subject_type: Mapped[str] = mapped_column(String(16), default="user")  # user | org
    subject_id: Mapped[str] = mapped_column(String(36), index=True)
    plan: Mapped[str] = mapped_column(String(20))
    status: Mapped[str] = mapped_column(String(20), index=True)  # active | canceled | expired
    provider: Mapped[str] = mapped_column(String(20))
    provider_reference: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    current_period_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class AIReviewRecord(Base):
    __tablename__ = "ai_answer_reviews"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    usage_event_id: Mapped[str] = mapped_column(ForeignKey("ai_usage_events.id"), unique=True, index=True)
    reviewer_user_id: Mapped[str] = mapped_column(String(36), index=True)
    verdict: Mapped[str] = mapped_column(String(24), index=True)
    notes: Mapped[str | None] = mapped_column(String(4000))
    reviewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


class AccountError(ValueError):
    pass


class AccountService:
    """Own authentication, contact consent, and idempotent alert delivery."""

    def __init__(
        self,
        database_url: str | None = None,
        secret: str | None = None,
        gateway: DeliveryGateway | None = None,
    ) -> None:
        resolved_secret = secret or os.getenv("KYR_APP_SECRET")
        if resolved_secret is None:
            raise RuntimeError("KYR_APP_SECRET is required")
        self.secret = resolved_secret
        self.jwt_secret = hashlib.sha256(self.secret.encode()).digest()
        self.gateway = gateway or DevelopmentGateway()
        self.public_base_url = os.getenv("KYR_PUBLIC_BASE_URL", "http://127.0.0.1:8000").rstrip("/")
        resolved_database = database_url or os.getenv("DATABASE_URL") or DEFAULT_DATABASE_URL
        connect_args = {"check_same_thread": False} if resolved_database.startswith("sqlite") else {}
        if resolved_database.endswith(":memory:"):
            self.engine = create_engine(
                resolved_database,
                connect_args=connect_args,
                poolclass=StaticPool,
            )
        else:
            self.engine = create_engine(resolved_database, connect_args=connect_args)
        if resolved_database.startswith("postgresql"):
            if not inspect(self.engine).has_table("users"):
                raise RuntimeError(
                    "PostgreSQL schema is not migrated; run `alembic upgrade head` before startup"
                )
        else:
            # SQLite remains a zero-setup local/test adapter. Production PostgreSQL is
            # migration-only so application startup can never mutate its schema.
            Base.metadata.create_all(self.engine)
        self.sessions = sessionmaker(self.engine, expire_on_commit=False)
        self.passwords = PasswordHasher()
        key = base64.urlsafe_b64encode(hashlib.sha256(self.secret.encode()).digest())
        self.cipher = Fernet(key)

    def register(self, email: str, password: str) -> str | None:
        normalized = email.strip().lower()
        with self.sessions.begin() as session:
            if session.scalar(select(UserRecord).where(UserRecord.email == normalized)):
                return None
            user = UserRecord(
                id=str(uuid.uuid4()),
                email=normalized,
                password_hash=self.passwords.hash(password),
                email_verified_at=None,
                created_at=self._now(),
            )
            session.add(user)
            session.add(UserRoleRecord(user_id=user.id, role="reader", updated_at=self._now()))
            token = self._new_verification(session, user.id, "email")
        self.gateway.send_email_verification(normalized, token)
        return token

    def email_exists(self, email: str) -> bool:
        normalized = email.strip().lower()
        with self.sessions() as session:
            return session.scalar(select(UserRecord.id).where(UserRecord.email == normalized)) is not None

    def verify_email(self, token: str) -> None:
        with self.sessions.begin() as session:
            record = self._consume_verification(session, token, "email")
            user = session.get(UserRecord, record.subject_id)
            if user is None:
                raise AccountError("invalid verification token")
            user.email_verified_at = self._now()

    def resend_email_verification(self, email: str) -> str | None:
        normalized = email.strip().lower()
        with self.sessions.begin() as session:
            user = session.scalar(select(UserRecord).where(UserRecord.email == normalized))
            if user is None or user.email_verified_at is not None:
                return None
            token = self._new_verification(session, user.id, "email")
        self.gateway.send_email_verification(normalized, token)
        return token

    def request_password_reset(self, email: str) -> str | None:
        normalized = email.strip().lower()
        with self.sessions.begin() as session:
            user = session.scalar(select(UserRecord).where(UserRecord.email == normalized))
            if user is None or user.email_verified_at is None:
                return None
            token = self._new_verification(session, user.id, "password_reset")
        self.gateway.send_password_reset(normalized, token)
        return token

    def reset_password(self, token: str, password: str) -> None:
        with self.sessions.begin() as session:
            record = self._consume_verification(session, token, "password_reset")
            user = session.get(UserRecord, record.subject_id)
            if user is None:
                raise AccountError("invalid password reset token")
            user.password_hash = self.passwords.hash(password)

    def login(self, email: str, password: str) -> str:
        with self.sessions() as session:
            user = session.scalar(select(UserRecord).where(UserRecord.email == email.strip().lower()))
            if user is None or user.email_verified_at is None:
                raise AccountError("invalid email or password")
            try:
                self.passwords.verify(user.password_hash, password)
            except VerifyMismatchError as error:
                raise AccountError("invalid email or password") from error
            return self._access_token(user.id)

    def authenticate(self, token: str) -> str:
        try:
            payload = jwt.decode(token, self.jwt_secret, algorithms=["HS256"])
        except jwt.PyJWTError as error:
            raise AccountError("invalid access token") from error
        return str(payload["sub"])

    def ensure_managed_user(self, user_id: str, email: str) -> None:
        """Mirror the minimum Supabase identity required by local app records."""
        with self.sessions.begin() as session:
            user = session.get(UserRecord, user_id)
            if user is None:
                normalized = email.strip().lower()
                legacy = session.scalar(select(UserRecord).where(UserRecord.email == normalized))
                if legacy is not None:
                    old_id = legacy.id
                    for model in (
                        ProfileRecord,
                        ContactRecord,
                        AlertRecord,
                        UserRoleRecord,
                        DeviceSessionRecord,
                    ):
                        session.execute(update(model).where(model.user_id == old_id).values(user_id=user_id))
                    session.delete(legacy)
                    session.flush()
                session.add(
                    UserRecord(
                        id=user_id,
                        email=normalized,
                        password_hash="managed-by-supabase",
                        email_verified_at=self._now(),
                        created_at=self._now(),
                    )
                )
                if session.get(UserRoleRecord, user_id) is None:
                    session.add(UserRoleRecord(user_id=user_id, role="reader", updated_at=self._now()))
            elif email and user.email != email.strip().lower():
                user.email = email.strip().lower()

    def active_plan(self, subject_id: str) -> str:
        """The subject's current plan, or 'free' when none is active or it lapsed."""
        from backend.billing import PLAN_FREE

        now = self._now()
        with self.sessions() as session:
            row = session.scalar(
                select(SubscriptionRecord)
                .where(
                    SubscriptionRecord.subject_id == subject_id,
                    SubscriptionRecord.status == "active",
                )
                .order_by(SubscriptionRecord.updated_at.desc())
            )
            if row is None:
                return PLAN_FREE
            if row.current_period_end is not None and _as_utc(row.current_period_end) < now:
                return PLAN_FREE
            return row.plan

    def ai_quota_for(self, subject_id: str | None) -> int:
        """Daily AI question quota for a subject; anonymous callers get free."""
        from backend.billing import PLAN_FREE, ai_daily_quota

        return ai_daily_quota(self.active_plan(subject_id) if subject_id else PLAN_FREE)

    def activate_subscription(
        self,
        *,
        subject_id: str,
        plan: str,
        provider: str,
        reference: str,
        subject_type: str = "user",
        period_days: int = 30,
    ) -> None:
        """Record a paid subscription. Idempotent on the provider reference, so a
        webhook delivered twice does not create two subscriptions."""
        from backend.billing import VALID_PLANS

        if plan not in VALID_PLANS:
            raise AccountError("unknown plan")
        now = self._now()
        with self.sessions.begin() as session:
            existing = session.scalar(
                select(SubscriptionRecord).where(SubscriptionRecord.provider_reference == reference)
            )
            if existing is not None:
                existing.status = "active"
                existing.plan = plan
                existing.current_period_end = now + timedelta(days=period_days)
                existing.updated_at = now
                return
            session.add(
                SubscriptionRecord(
                    id=str(uuid.uuid4()),
                    subject_type=subject_type,
                    subject_id=subject_id,
                    plan=plan,
                    status="active",
                    provider=provider,
                    provider_reference=reference,
                    current_period_end=now + timedelta(days=period_days),
                    created_at=now,
                    updated_at=now,
                )
            )

    # A checkout is created for one user, then confirmed by a provider webhook
    # that only carries the reference. We record the reference->user binding as an
    # inactive subscription row so the webhook can activate the right account -
    # and never activate an account from an unbound reference.

    def record_pending_checkout(self, reference: str, user_id: str, plan: str) -> None:
        from backend.billing import VALID_PLANS

        if plan not in VALID_PLANS:
            raise AccountError("unknown plan")
        now = self._now()
        with self.sessions.begin() as session:
            session.add(
                SubscriptionRecord(
                    id=str(uuid.uuid4()),
                    subject_type="user",
                    subject_id=user_id,
                    plan=plan,
                    status="pending",
                    provider="pending",
                    provider_reference=reference,
                    current_period_end=None,
                    created_at=now,
                    updated_at=now,
                )
            )

    def fulfil_checkout(self, reference: str, plan: str, provider: str, period_days: int = 30) -> bool:
        """Activate the subscription for a paid reference. Idempotent; ignores
        references we never issued, so a forged webhook cannot grant a plan."""
        now = self._now()
        with self.sessions.begin() as session:
            row = session.scalar(
                select(SubscriptionRecord).where(SubscriptionRecord.provider_reference == reference)
            )
            if row is None:
                return False  # unknown reference — do not activate anything
            row.status = "active"
            row.plan = plan
            row.provider = provider
            row.current_period_end = now + timedelta(days=period_days)
            row.updated_at = now
            return True

    def subscription_status(self, subject_id: str) -> dict:
        """What a user sees on their billing screen."""
        plan = self.active_plan(subject_id)
        with self.sessions() as session:
            row = session.scalar(
                select(SubscriptionRecord)
                .where(SubscriptionRecord.subject_id == subject_id)
                .order_by(SubscriptionRecord.updated_at.desc())
            )
        return {
            "plan": plan,
            "status": row.status if row else "none",
            "current_period_end": (
                row.current_period_end.isoformat() if row and row.current_period_end else None
            ),
        }

    def role(self, user_id: str) -> str:
        with self.sessions() as session:
            record = session.get(UserRoleRecord, user_id)
            return record.role if record else "reader"

    def set_role(self, actor_id: str, user_id: str, role: str) -> None:
        allowed = {"reader", "contributor", "reviewer", "administrator"}
        if role not in allowed:
            raise AccountError("invalid role")
        if self.role(actor_id) != "administrator":
            raise AccountError("administrator role required")
        with self.sessions.begin() as session:
            record = session.get(UserRoleRecord, user_id)
            if record is None:
                session.add(UserRoleRecord(user_id=user_id, role=role, updated_at=self._now()))
            else:
                record.role = role
                record.updated_at = self._now()

    def record_device(
        self,
        user_id: str,
        session_id: str,
        device_id: str,
        device_name: str,
    ) -> None:
        device_hash = hashlib.sha256(device_id.encode()).hexdigest()
        with self.sessions.begin() as session:
            record = session.get(DeviceSessionRecord, session_id)
            if record is None:
                session.add(
                    DeviceSessionRecord(
                        session_id=session_id,
                        user_id=user_id,
                        device_id_hash=device_hash,
                        device_name=device_name[:120] or "Unknown device",
                        first_seen_at=self._now(),
                        last_seen_at=self._now(),
                        revoked_at=None,
                    )
                )
            else:
                record.last_seen_at = self._now()
                record.device_name = device_name[:120] or record.device_name

    def device_sessions(self, user_id: str) -> list[dict]:
        with self.sessions() as session:
            rows = session.scalars(
                select(DeviceSessionRecord)
                .where(DeviceSessionRecord.user_id == user_id)
                .order_by(DeviceSessionRecord.last_seen_at.desc())
            ).all()
            return [
                {
                    "session_id": row.session_id,
                    "device_name": row.device_name,
                    "first_seen_at": row.first_seen_at,
                    "last_seen_at": row.last_seen_at,
                    "revoked": row.revoked_at is not None,
                }
                for row in rows
            ]

    def session_allowed(self, user_id: str, session_id: str) -> bool:
        with self.sessions() as session:
            record = session.get(DeviceSessionRecord, session_id)
            return record is None or (record.user_id == user_id and record.revoked_at is None)

    def revoke_device_session(
        self,
        user_id: str,
        session_id: str,
        current_session_id: str | None,
    ) -> None:
        if session_id == current_session_id:
            raise AccountError("use sign out to close the current session")
        with self.sessions.begin() as session:
            record = session.get(DeviceSessionRecord, session_id)
            if record is None or record.user_id != user_id:
                raise AccountError("session not found")
            record.revoked_at = self._now()

    def check_rate_limit(self, key: str, limit: int, window_seconds: int) -> bool:
        """Persist rate-limit events so limits survive restarts and multiple workers."""
        key_hash = hashlib.sha256(key.encode()).hexdigest()
        cutoff = self._now() - timedelta(seconds=window_seconds)
        with self.sessions.begin() as session:
            session.execute(delete(AbuseEventRecord).where(AbuseEventRecord.occurred_at < cutoff))
            count = session.scalar(
                select(func.count())
                .select_from(AbuseEventRecord)
                .where(
                    AbuseEventRecord.key_hash == key_hash,
                    AbuseEventRecord.occurred_at >= cutoff,
                )
            )
            if int(count or 0) >= limit:
                return False
            session.add(
                AbuseEventRecord(
                    id=str(uuid.uuid4()),
                    key_hash=key_hash,
                    occurred_at=self._now(),
                )
            )
            return True

    def ai_cache_get(self, cache_key: str) -> dict | None:
        now = self._now()
        with self.sessions.begin() as session:
            row = session.get(AIAnswerCacheRecord, cache_key)
            expires_at = row.expires_at if row is not None else None
            if expires_at is not None and expires_at.tzinfo is None:
                expires_at = expires_at.replace(tzinfo=UTC)
            if row is None or expires_at is None or expires_at <= now:
                if row is not None:
                    session.delete(row)
                return None
            row.hits += 1
            return json.loads(row.response_json)

    def ai_cache_put(
        self,
        cache_key: str,
        response: dict,
        *,
        content_version: int,
        model_key: str,
        ttl_seconds: int,
    ) -> None:
        now = self._now()
        with self.sessions.begin() as session:
            row = session.get(AIAnswerCacheRecord, cache_key)
            values = {
                "response_json": json.dumps(response),
                "content_version": content_version,
                "model_key": model_key,
                "expires_at": now + timedelta(seconds=ttl_seconds),
                "created_at": now,
            }
            if row:
                for key, value in values.items():
                    setattr(row, key, value)
            else:
                session.add(AIAnswerCacheRecord(cache_key=cache_key, hits=0, **values))

    def ai_daily_usage(self, privacy_id: str) -> int:
        start = self._now().replace(hour=0, minute=0, second=0, microsecond=0)
        with self.sessions() as session:
            return int(
                session.scalar(
                    select(func.count()).where(
                        AIUsageRecord.privacy_id == privacy_id,
                        AIUsageRecord.created_at >= start,
                        AIUsageRecord.cache_hit.is_(False),
                    )
                )
                or 0
            )

    def record_ai_usage(
        self,
        *,
        privacy_id: str,
        user_id: str | None,
        corpus: str,
        jurisdiction: str,
        model_key: str,
        latency_ms: int,
        input_tokens: int,
        output_tokens: int,
        estimated_cost_usd: float,
        cache_hit: bool,
        refused: bool,
        response: dict,
        sample_rate: float,
    ) -> str:
        event_id = str(uuid.uuid4())
        sample_digest = hashlib.sha256(f"{event_id}:{privacy_id}".encode()).digest()
        sampled = int.from_bytes(sample_digest[:4], "big") / 2**32 < sample_rate
        with self.sessions.begin() as session:
            session.add(
                AIUsageRecord(
                    id=event_id,
                    privacy_id=privacy_id,
                    user_id=user_id,
                    corpus=corpus,
                    jurisdiction=jurisdiction,
                    model_key=model_key,
                    latency_ms=latency_ms,
                    input_tokens=input_tokens,
                    output_tokens=output_tokens,
                    estimated_cost_usd=estimated_cost_usd,
                    cache_hit=cache_hit,
                    refused=refused,
                    sampled_for_review=sampled,
                    response_json=json.dumps(response) if sampled else None,
                    created_at=self._now(),
                )
            )
        return event_id

    def ai_metrics_summary(self, days: int = 7) -> dict:
        """Aggregate LLM cost, latency, cache, and refusal rates over a window.

        The prompts themselves are never stored, so this reports on volume and
        cost without exposing what anyone asked.
        """
        since = self._now() - timedelta(days=days)
        with self.sessions() as session:
            rows = session.scalars(select(AIUsageRecord).where(AIUsageRecord.created_at >= since)).all()
        total = len(rows)
        if total == 0:
            return {"window_days": days, "questions": 0}
        latencies = sorted(r.latency_ms for r in rows)
        p95 = latencies[min(len(latencies) - 1, int(len(latencies) * 0.95))]
        by_corpus: dict[str, int] = {}
        for r in rows:
            by_corpus[r.corpus] = by_corpus.get(r.corpus, 0) + 1
        return {
            "window_days": days,
            "questions": total,
            "refused": sum(1 for r in rows if r.refused),
            "refusal_rate": round(sum(1 for r in rows if r.refused) / total, 3),
            "cache_hit_rate": round(sum(1 for r in rows if r.cache_hit) / total, 3),
            "estimated_cost_usd": round(sum(r.estimated_cost_usd for r in rows), 4),
            "latency_ms_avg": round(sum(latencies) / total, 1),
            "latency_ms_p95": p95,
            "by_corpus": by_corpus,
        }

    def error_report_metrics(self) -> dict:
        """Open vs resolved error reports and how long resolution takes."""
        from backend.review import ErrorReportRecord

        with self.sessions() as session:
            rows = session.scalars(select(ErrorReportRecord)).all()
        open_count = sum(1 for r in rows if r.status in ("open", "triaged"))
        resolved = [r for r in rows if r.resolved_at is not None]
        hours = [(r.resolved_at - r.created_at).total_seconds() / 3600 for r in resolved]
        return {
            "open": open_count,
            "resolved": len(resolved),
            "avg_resolution_hours": round(sum(hours) / len(hours), 1) if hours else None,
        }

    def pending_ai_reviews(self, limit: int = 50) -> list[dict]:
        with self.sessions() as session:
            rows = session.scalars(
                select(AIUsageRecord)
                .outerjoin(AIReviewRecord, AIReviewRecord.usage_event_id == AIUsageRecord.id)
                .where(
                    AIUsageRecord.sampled_for_review.is_(True),
                    AIReviewRecord.id.is_(None),
                )
                .order_by(AIUsageRecord.created_at)
                .limit(limit)
            ).all()
            return [
                {
                    "id": row.id,
                    "corpus": row.corpus,
                    "jurisdiction": row.jurisdiction,
                    "response": json.loads(row.response_json or "{}"),
                    "created_at": row.created_at,
                }
                for row in rows
            ]

    def review_ai_answer(
        self,
        usage_event_id: str,
        reviewer_user_id: str,
        verdict: str,
        notes: str | None,
    ) -> None:
        if verdict not in {"pass", "citation_error", "unsafe", "incorrect", "other"}:
            raise AccountError("invalid review verdict")
        with self.sessions.begin() as session:
            if session.get(AIUsageRecord, usage_event_id) is None:
                raise AccountError("AI answer sample not found")
            existing = session.scalar(
                select(AIReviewRecord).where(AIReviewRecord.usage_event_id == usage_event_id)
            )
            if existing:
                raise AccountError("AI answer sample has already been reviewed")
            session.add(
                AIReviewRecord(
                    id=str(uuid.uuid4()),
                    usage_event_id=usage_event_id,
                    reviewer_user_id=reviewer_user_id,
                    verdict=verdict,
                    notes=notes,
                    reviewed_at=self._now(),
                )
            )

    def export_account(self, user_id: str) -> dict:
        profile = self.profile(user_id)
        contacts = self.contacts(user_id)
        with self.sessions() as session:
            alerts = session.scalars(
                select(AlertRecord)
                .where(AlertRecord.user_id == user_id)
                .order_by(AlertRecord.triggered_at.desc())
            ).all()
            return {
                "exported_at": self._now().isoformat(),
                "profile": profile,
                "role": self.role(user_id),
                "emergency_contacts": contacts,
                "custody_alerts": [self._alert_dict(session, alert) for alert in alerts],
            }

    def delete_account_data(self, user_id: str) -> None:
        with self.sessions.begin() as session:
            alerts = session.scalars(select(AlertRecord).where(AlertRecord.user_id == user_id)).all()
            for alert in alerts:
                for delivery in session.scalars(
                    select(AlertDeliveryRecord).where(AlertDeliveryRecord.alert_id == alert.id)
                ).all():
                    session.delete(delivery)
                session.delete(alert)
            contacts = session.scalars(select(ContactRecord).where(ContactRecord.user_id == user_id)).all()
            contact_ids = {contact.id for contact in contacts}
            for token in session.scalars(select(VerificationRecord)).all():
                if token.subject_id == user_id or token.subject_id in contact_ids:
                    session.delete(token)
            for contact in contacts:
                channel = session.get(ContactChannelRecord, contact.id)
                if channel is not None:
                    session.delete(channel)
                session.delete(contact)
            for model in (ProfileRecord, UserRoleRecord):
                record = session.get(model, user_id)
                if record is not None:
                    session.delete(record)
            for device in session.scalars(
                select(DeviceSessionRecord).where(DeviceSessionRecord.user_id == user_id)
            ).all():
                session.delete(device)
            user = session.get(UserRecord, user_id)
            if user is not None:
                session.delete(user)

    def update_profile(self, user_id: str, full_name: str, phone: str) -> None:
        with self.sessions.begin() as session:
            profile = session.get(ProfileRecord, user_id)
            clean_name = full_name.strip()
            encrypted_phone = self._encrypt(phone)
            completed_at = self._now()
            if profile is None:
                session.add(
                    ProfileRecord(
                        user_id=user_id,
                        full_name=clean_name,
                        phone_encrypted=encrypted_phone,
                        completed_at=completed_at,
                    )
                )
            else:
                profile.full_name = clean_name
                profile.phone_encrypted = encrypted_phone
                profile.completed_at = completed_at

    def profile(self, user_id: str) -> dict:
        with self.sessions() as session:
            user = session.get(UserRecord, user_id)
            profile = session.get(ProfileRecord, user_id)
            if user is None:
                raise AccountError("account not found")
            phone = self._decrypt_or_none(profile.phone_encrypted) if profile else None
            return {
                "email": user.email,
                "email_verified": user.email_verified_at is not None,
                "full_name": profile.full_name if profile else None,
                "phone": phone,
                "onboarding_complete": profile is not None and phone is not None,
            }

    def sync_user_items(self, user_id: str, items: list[dict]) -> list[dict]:
        """Last-write-wins sync for a user's saved items and private drafts."""
        # saved: bookmarked cases/topics. draft: private work in progress.
        # reading_list: a named list of case ids. preference: client settings
        # such as law-student mode, which must survive a reinstall.
        # history: recently-viewed content; preference: client settings
        # (theme, notifications, accessibility) that must survive a reinstall.
        allowed = {"saved", "draft", "reading_list", "preference", "history"}
        with self.sessions.begin() as session:
            for item in items:
                if item["kind"] not in allowed:
                    raise AccountError("unsupported sync item kind")
                updated_at = item["updated_at"]
                existing = session.scalar(
                    select(UserSyncRecord).where(
                        UserSyncRecord.user_id == user_id,
                        UserSyncRecord.kind == item["kind"],
                        UserSyncRecord.item_id == item["item_id"],
                    )
                )
                # SQLite hands back naive datetimes even for timezone-aware
                # columns, so normalise both sides before the last-write-wins
                # comparison; otherwise every update to an existing item raises.
                if existing and _as_utc(existing.updated_at) >= _as_utc(updated_at):
                    continue
                values = {
                    "payload_json": json.dumps(item.get("payload") or {}),
                    "deleted": bool(item.get("deleted")),
                    "updated_at": updated_at,
                }
                if existing:
                    for key, value in values.items():
                        setattr(existing, key, value)
                else:
                    session.add(
                        UserSyncRecord(
                            id=str(uuid.uuid4()),
                            user_id=user_id,
                            kind=item["kind"],
                            item_id=item["item_id"],
                            **values,
                        )
                    )
        return self.user_items(user_id)

    def user_items(self, user_id: str, since: datetime | None = None) -> list[dict]:
        with self.sessions() as session:
            query = select(UserSyncRecord).where(UserSyncRecord.user_id == user_id)
            if since:
                query = query.where(UserSyncRecord.updated_at > since)
            rows = session.scalars(query.order_by(UserSyncRecord.updated_at)).all()
            return [
                {
                    "kind": row.kind,
                    "item_id": row.item_id,
                    "payload": json.loads(row.payload_json),
                    "deleted": row.deleted,
                    "updated_at": row.updated_at,
                }
                for row in rows
            ]

    def create_contact(
        self,
        user_id: str,
        name: str,
        phone: str,
        email: str | None = None,
        channels: list[str] | None = None,
        push_token: str | None = None,
    ) -> tuple[dict, str]:
        selected = set(channels or ["sms"])
        with self.sessions.begin() as session:
            active_count = session.scalar(
                select(func.count())
                .select_from(ContactRecord)
                .where(
                    ContactRecord.user_id == user_id,
                    ContactRecord.status.in_(("pending", "verified")),
                )
            )
            if int(active_count or 0) >= 3:
                raise AccountError("you can configure up to three emergency contacts")
            contact = ContactRecord(
                id=str(uuid.uuid4()),
                user_id=user_id,
                name=name.strip(),
                phone_encrypted=self._encrypt(phone),
                status="pending",
                verified_at=None,
                created_at=self._now(),
            )
            session.add(contact)
            session.add(
                ContactChannelRecord(
                    contact_id=contact.id,
                    email_encrypted=self._encrypt(email.strip()) if email else None,
                    push_token_encrypted=(self._encrypt(push_token.strip()) if push_token else None),
                    whatsapp_enabled="whatsapp" in selected,
                    email_enabled="email" in selected and bool(email),
                    push_enabled="push" in selected and bool(push_token),
                )
            )
            token = self._new_verification(session, contact.id, "contact")
            decline_token = self._new_verification(session, contact.id, "contact_decline")
            withdrawal_token = self._new_verification(
                session,
                contact.id,
                "contact_withdraw",
                ttl=timedelta(days=365),
            )
        self.gateway.send_contact_verification(
            phone,
            contact.name,
            token,
            decline_token,
            withdrawal_token,
        )
        return self._contact_dict(contact), token

    def verify_contact(self, token: str) -> None:
        with self.sessions.begin() as session:
            record = self._consume_verification(session, token, "contact")
            contact = session.get(ContactRecord, record.subject_id)
            if contact is None or contact.status != "pending":
                raise AccountError("invalid verification token")
            contact.status = "verified"
            contact.verified_at = self._now()

    def decline_contact(self, token: str) -> None:
        with self.sessions.begin() as session:
            record = self._consume_verification(session, token, "contact_decline")
            contact = session.get(ContactRecord, record.subject_id)
            if contact is None or contact.status != "pending":
                raise AccountError("invalid contact decline token")
            contact.status = "declined"

    def withdraw_contact(self, token: str) -> None:
        with self.sessions.begin() as session:
            record = self._consume_verification(session, token, "contact_withdraw")
            contact = session.get(ContactRecord, record.subject_id)
            if contact is None or contact.status not in {"pending", "verified"}:
                raise AccountError("invalid contact withdrawal token")
            contact.status = "withdrawn"
            contact.verified_at = None

    def contacts(self, user_id: str) -> list[dict]:
        with self.sessions() as session:
            rows = session.scalars(select(ContactRecord).where(ContactRecord.user_id == user_id)).all()
            contacts = []
            for row in rows:
                phone = self._decrypt_or_none(row.phone_encrypted)
                if phone is not None:
                    contacts.append(
                        {
                            "id": row.id,
                            "name": row.name,
                            "phone": phone,
                            "status": row.status,
                            **self._contact_channel_dict(session, row.id),
                        }
                    )
            return contacts

    def delete_contact(self, user_id: str, contact_id: str) -> None:
        with self.sessions.begin() as session:
            contact = session.get(ContactRecord, contact_id)
            if contact is None or contact.user_id != user_id:
                raise AccountError("contact not found")
            contact.status = "revoked"

    def create_alert(
        self,
        user_id: str,
        contact_id: str,
        idempotency_key: str,
        latitude: float | None,
        longitude: float | None,
        accuracy: float | None,
        station_name: str | None = None,
        is_test: bool = False,
    ) -> tuple[dict, bool]:
        with self.sessions.begin() as session:
            existing = session.scalar(
                select(AlertRecord).where(
                    AlertRecord.user_id == user_id,
                    AlertRecord.idempotency_key == idempotency_key,
                )
            )
            if existing:
                return self._alert_dict(session, existing), True
            profile = session.get(ProfileRecord, user_id)
            contact = session.get(ContactRecord, contact_id)
            if profile is None:
                raise AccountError("complete your profile before sending an alert")
            if contact is None or contact.user_id != user_id or contact.status != "verified":
                raise AccountError("a verified emergency contact is required")
            alert = AlertRecord(
                id=str(uuid.uuid4()),
                user_id=user_id,
                contact_id=contact.id,
                idempotency_key=idempotency_key,
                latitude_encrypted=self._encrypt(str(latitude)) if latitude is not None else None,
                longitude_encrypted=self._encrypt(str(longitude)) if longitude is not None else None,
                accuracy=accuracy,
                status="queued",
                provider_message_id=None,
                triggered_at=self._now(),
            )
            session.add(alert)
            session.flush()
            public_token = secrets.token_urlsafe(32)
            session.add(
                AlertMetadataRecord(
                    alert_id=alert.id,
                    public_token_hash=self._token_hash(public_token),
                    public_token_encrypted=self._encrypt(public_token),
                    station_name_encrypted=(
                        self._encrypt(station_name.strip()) if station_name and station_name.strip() else None
                    ),
                    is_test=is_test,
                )
            )
            delivery = AlertDeliveryRecord(
                id=str(uuid.uuid4()),
                alert_id=alert.id,
                channel="gateway_sms",
                status="queued",
                attempts=0,
                provider_message_id=None,
                last_error=None,
                next_retry_at=None,
                created_at=self._now(),
                updated_at=self._now(),
            )
            session.add(delivery)
            session.flush()
            self._attempt_delivery(
                session,
                alert,
                delivery,
                contact,
                self._alert_message(profile, alert, session),
            )
            self._attempt_optional_deliveries(
                session,
                alert,
                contact,
                self._alert_message(profile, alert, session),
            )
            return self._alert_dict(session, alert), False

    def alert_history(self, user_id: str, limit: int = 50) -> list[dict]:
        with self.sessions() as session:
            alerts = session.scalars(
                select(AlertRecord)
                .where(AlertRecord.user_id == user_id)
                .order_by(AlertRecord.triggered_at.desc())
                .limit(min(max(limit, 1), 100))
            ).all()
            return [self._alert_dict(session, alert) for alert in alerts]

    def public_alert(self, token: str) -> dict:
        with self.sessions() as session:
            metadata = session.scalar(
                select(AlertMetadataRecord).where(
                    AlertMetadataRecord.public_token_hash == self._token_hash(token)
                )
            )
            if metadata is None:
                raise AccountError("alert status not found")
            alert = session.get(AlertRecord, metadata.alert_id)
            if alert is None:
                raise AccountError("alert status not found")
            profile = session.get(ProfileRecord, alert.user_id)
            result = self._alert_dict(session, alert)
            result["sender_name"] = profile.full_name if profile else "The sender"
            result["location_url"] = self._location_url(alert)
            return result

    def arm_check_in(
        self,
        user_id: str,
        minutes: int,
        station_name: str | None = None,
    ) -> dict:
        if minutes < 1 or minutes > 24 * 60:
            raise AccountError("check-in timer must be between 1 minute and 24 hours")
        with self.sessions.begin() as session:
            if session.get(ProfileRecord, user_id) is None:
                raise AccountError("complete your profile before starting Safe Walk")
            verified = session.scalar(
                select(func.count())
                .select_from(ContactRecord)
                .where(
                    ContactRecord.user_id == user_id,
                    ContactRecord.status == "verified",
                )
            )
            if int(verified or 0) == 0:
                raise AccountError("a verified emergency contact is required")
            for existing in session.scalars(
                select(CheckInRecord).where(
                    CheckInRecord.user_id == user_id,
                    CheckInRecord.status == "armed",
                )
            ).all():
                existing.status = "cancelled"
                existing.completed_at = self._now()
            record = CheckInRecord(
                id=str(uuid.uuid4()),
                user_id=user_id,
                due_at=self._now() + timedelta(minutes=minutes),
                status="armed",
                station_name_encrypted=(
                    self._encrypt(station_name.strip()) if station_name and station_name.strip() else None
                ),
                created_at=self._now(),
                completed_at=None,
            )
            session.add(record)
            return self._check_in_dict(record)

    def active_check_in(self, user_id: str) -> dict | None:
        with self.sessions() as session:
            record = session.scalar(
                select(CheckInRecord)
                .where(
                    CheckInRecord.user_id == user_id,
                    CheckInRecord.status == "armed",
                )
                .order_by(CheckInRecord.created_at.desc())
            )
            return self._check_in_dict(record) if record else None

    def complete_check_in(self, user_id: str, check_in_id: str) -> dict:
        with self.sessions.begin() as session:
            record = session.get(CheckInRecord, check_in_id)
            if record is None or record.user_id != user_id:
                raise AccountError("check-in not found")
            if record.status != "armed":
                return self._check_in_dict(record)
            record.status = "safe"
            record.completed_at = self._now()
            return self._check_in_dict(record)

    def process_due_check_ins(self) -> int:
        due: list[tuple[str, str, str | None]] = []
        with self.sessions.begin() as session:
            records = session.scalars(
                select(CheckInRecord).where(
                    CheckInRecord.status == "armed",
                    CheckInRecord.due_at <= self._now(),
                )
            ).all()
            for record in records:
                record.status = "firing"
                station = (
                    self._decrypt_or_none(record.station_name_encrypted)
                    if record.station_name_encrypted
                    else None
                )
                due.append((record.id, record.user_id, station))
        fired = 0
        for check_in_id, user_id, station in due:
            with self.sessions() as session:
                contacts = session.scalars(
                    select(ContactRecord).where(
                        ContactRecord.user_id == user_id,
                        ContactRecord.status == "verified",
                    )
                ).all()
                contact_ids = [contact.id for contact in contacts[:3]]
            for index, contact_id in enumerate(contact_ids):
                self.create_alert(
                    user_id,
                    contact_id,
                    f"safe-walk-{check_in_id}-{index}",
                    None,
                    None,
                    None,
                    station,
                    False,
                )
            with self.sessions.begin() as session:
                record = session.get(CheckInRecord, check_in_id)
                if record is not None:
                    record.status = "fired"
                    record.completed_at = self._now()
            fired += 1
        return fired

    def _check_in_dict(self, record: CheckInRecord) -> dict:
        return {
            "id": record.id,
            "status": record.status,
            "due_at": self._aware(record.due_at),
            "created_at": self._aware(record.created_at),
        }

    def get_alert(self, user_id: str, alert_id: str) -> dict:
        with self.sessions() as session:
            alert = session.get(AlertRecord, alert_id)
            if alert is None or alert.user_id != user_id:
                raise AccountError("alert not found")
            return self._alert_dict(session, alert)

    def cancel_alert(self, user_id: str, alert_id: str) -> dict:
        with self.sessions.begin() as session:
            alert = self._owned_alert(session, user_id, alert_id)
            if alert.status in {"cancelled", "resolved"}:
                return self._alert_dict(session, alert)
            previous_status = alert.status
            alert.status = "cancelled"
            if previous_status in {"sent", "delivered"}:
                self._send_follow_up(
                    session,
                    alert,
                    "FALSE ALARM: The earlier Know Your Rights custody alert was cancelled.",
                )
            return self._alert_dict(session, alert)

    def resolve_alert(self, user_id: str, alert_id: str) -> dict:
        with self.sessions.begin() as session:
            alert = self._owned_alert(session, user_id, alert_id)
            if alert.status == "cancelled":
                raise AccountError("a cancelled alert cannot be resolved")
            previous_status = alert.status
            alert.status = "resolved"
            if previous_status in {"sent", "delivered"}:
                self._send_follow_up(
                    session,
                    alert,
                    "SAFE UPDATE: The sender of the earlier Know Your Rights custody "
                    "alert has marked themselves safe.",
                )
            return self._alert_dict(session, alert)

    def retry_alert(self, user_id: str, alert_id: str) -> dict:
        with self.sessions.begin() as session:
            alert = self._owned_alert(session, user_id, alert_id)
            if alert.status != "failed":
                raise AccountError("only a failed alert can be retried")
            contact = session.get(ContactRecord, alert.contact_id)
            profile = session.get(ProfileRecord, user_id)
            delivery = session.scalar(
                select(AlertDeliveryRecord)
                .where(AlertDeliveryRecord.alert_id == alert.id)
                .order_by(AlertDeliveryRecord.created_at.desc())
            )
            if contact is None or profile is None or delivery is None:
                raise AccountError("alert delivery data is incomplete")
            message = self._alert_message(profile, alert, session)
            self._attempt_delivery(session, alert, delivery, contact, message)
            return self._alert_dict(session, alert)

    def retry_due_alerts(self, max_attempts: int = 3) -> int:
        """Retry failed SMS deliveries that have reached their backoff time."""
        retried = 0
        with self.sessions.begin() as session:
            deliveries = session.scalars(
                select(AlertDeliveryRecord).where(
                    AlertDeliveryRecord.status == "failed",
                    AlertDeliveryRecord.next_retry_at <= self._now(),
                    AlertDeliveryRecord.attempts < max_attempts,
                )
            ).all()
            for delivery in deliveries:
                alert = session.get(AlertRecord, delivery.alert_id)
                if alert is None or alert.status != "failed":
                    continue
                contact = session.get(ContactRecord, alert.contact_id)
                profile = session.get(ProfileRecord, alert.user_id)
                if contact is None or profile is None or contact.status != "verified":
                    continue
                message = self._alert_message(profile, alert, session)
                if delivery.channel == "gateway_sms":
                    self._attempt_delivery(session, alert, delivery, contact, message)
                else:
                    self._attempt_secondary_delivery(session, delivery, contact, message)
                retried += 1
        return retried

    def update_delivery(self, provider_message_id: str, status: str) -> dict:
        if status not in {"queued", "sent", "delivered", "failed"}:
            raise AccountError("invalid delivery status")
        with self.sessions.begin() as session:
            delivery = session.scalar(
                select(AlertDeliveryRecord).where(
                    AlertDeliveryRecord.provider_message_id == provider_message_id
                )
            )
            if delivery is None:
                raise AccountError("delivery not found")
            alert = session.get(AlertRecord, delivery.alert_id)
            if alert is None:
                raise AccountError("alert not found")
            delivery.status = status
            delivery.updated_at = self._now()
            delivery.next_retry_at = self._now() + timedelta(seconds=30) if status == "failed" else None
            if alert.status in {"cancelled", "resolved"}:
                return self._alert_dict(session, alert)
            alert.status = status
            return self._alert_dict(session, alert)

    def process_delivery_callback(
        self,
        event_id: str,
        provider_message_id: str,
        status: str,
    ) -> dict:
        event_hash = self._token_hash(event_id)
        with self.sessions.begin() as session:
            if session.get(WebhookEventRecord, event_hash) is not None:
                delivery = session.scalar(
                    select(AlertDeliveryRecord).where(
                        AlertDeliveryRecord.provider_message_id == provider_message_id
                    )
                )
                if delivery is None:
                    raise AccountError("delivery not found")
                alert = session.get(AlertRecord, delivery.alert_id)
                if alert is None:
                    raise AccountError("alert not found")
                return self._alert_dict(session, alert)
            session.add(
                WebhookEventRecord(
                    event_id_hash=event_hash,
                    received_at=self._now(),
                )
            )
        return self.update_delivery(provider_message_id, status)

    def purge_expired_locations(self, retention: timedelta = timedelta(hours=24)) -> int:
        cutoff = self._now() - retention
        purged = 0
        with self.sessions.begin() as session:
            alerts = session.scalars(select(AlertRecord).where(AlertRecord.triggered_at < cutoff)).all()
            for alert in alerts:
                if alert.latitude_encrypted is not None or alert.longitude_encrypted is not None:
                    alert.latitude_encrypted = None
                    alert.longitude_encrypted = None
                    alert.accuracy = None
                    purged += 1
        return purged

    def purge_retention(self, retention_days: dict[str, int]) -> int:
        """Enforce the data-retention schedule with real deletes.

        Driven by the schedule in `backend.retention`, so the policy and the code
        that enforces it cannot drift. Content and the audit log are intentionally
        not touched here. Returns the total rows deleted.
        """
        now = self._now()
        deleted = 0

        def cutoff(data_class: str) -> datetime:
            return now - timedelta(days=retention_days[data_class])

        with self.sessions.begin() as session:
            # Aggregate AI telemetry (no prompt text) beyond its window.
            deleted += session.execute(
                delete(AIUsageRecord).where(AIUsageRecord.created_at < cutoff("ai_usage_telemetry"))
            ).rowcount
            # Expired cache entries (also bounded by each row's own TTL).
            deleted += session.execute(
                delete(AIAnswerCacheRecord).where(AIAnswerCacheRecord.expires_at < now)
            ).rowcount
            # Abuse counters and used/expired verification tokens.
            deleted += session.execute(
                delete(AbuseEventRecord).where(AbuseEventRecord.occurred_at < cutoff("abuse_events"))
            ).rowcount
            deleted += session.execute(
                delete(VerificationRecord).where(
                    VerificationRecord.expires_at < cutoff("verification_tokens")
                )
            ).rowcount
            deleted += session.execute(
                delete(WebhookEventRecord).where(WebhookEventRecord.received_at < cutoff("webhook_events"))
            ).rowcount
        return deleted

    def _attempt_delivery(
        self,
        session: Session,
        alert: AlertRecord,
        delivery: AlertDeliveryRecord,
        contact: ContactRecord,
        message: str,
    ) -> None:
        delivery.attempts += 1
        delivery.updated_at = self._now()
        try:
            provider_id = self.gateway.send_custody_alert(
                self._decrypt(contact.phone_encrypted),
                message,
            )
            alert.provider_message_id = provider_id
            alert.status = "sent"
            delivery.provider_message_id = provider_id
            delivery.status = "sent"
            delivery.last_error = None
            delivery.next_retry_at = None
        except DeliveryError:
            alert.status = "failed"
            delivery.status = "failed"
            delivery.last_error = "SMS provider did not accept the alert"
            backoff_seconds = min(30 * (2 ** max(delivery.attempts - 1, 0)), 300)
            delivery.next_retry_at = self._now() + timedelta(seconds=backoff_seconds)
        session.flush()

    def _attempt_optional_deliveries(
        self,
        session: Session,
        alert: AlertRecord,
        contact: ContactRecord,
        message: str,
    ) -> None:
        preferences = session.get(ContactChannelRecord, contact.id)
        if preferences is None:
            return
        channels: list[str] = []
        if preferences.whatsapp_enabled:
            channels.append("whatsapp")
        if preferences.email_enabled and preferences.email_encrypted:
            channels.append("email")
        if preferences.push_enabled and preferences.push_token_encrypted:
            channels.append("push")
        for channel in channels:
            delivery = AlertDeliveryRecord(
                id=str(uuid.uuid4()),
                alert_id=alert.id,
                channel=channel,
                status="queued",
                attempts=0,
                provider_message_id=None,
                last_error=None,
                next_retry_at=None,
                created_at=self._now(),
                updated_at=self._now(),
            )
            session.add(delivery)
            self._attempt_secondary_delivery(session, delivery, contact, message, preferences)

    def _attempt_secondary_delivery(
        self,
        session: Session,
        delivery: AlertDeliveryRecord,
        contact: ContactRecord,
        message: str,
        preferences: ContactChannelRecord | None = None,
    ) -> None:
        preferences = preferences or session.get(ContactChannelRecord, contact.id)
        destination = None
        if delivery.channel == "whatsapp":
            destination = self._decrypt(contact.phone_encrypted)
        elif delivery.channel == "email" and preferences and preferences.email_encrypted:
            destination = self._decrypt(preferences.email_encrypted)
        elif delivery.channel == "push" and preferences and preferences.push_token_encrypted:
            destination = self._decrypt(preferences.push_token_encrypted)
        delivery.attempts += 1
        delivery.updated_at = self._now()
        try:
            if destination is None or not hasattr(self.gateway, "send_custody_alert_channel"):
                raise DeliveryError(f"{delivery.channel} delivery is not configured")
            delivery.provider_message_id = self.gateway.send_custody_alert_channel(
                delivery.channel, destination, message
            )
            delivery.status = "sent"
            delivery.last_error = None
            delivery.next_retry_at = None
        except DeliveryError:
            delivery.status = "failed"
            delivery.last_error = f"{delivery.channel} provider did not accept the alert"
            backoff_seconds = min(30 * (2 ** max(delivery.attempts - 1, 0)), 300)
            delivery.next_retry_at = self._now() + timedelta(seconds=backoff_seconds)
        session.flush()

    def _send_follow_up(
        self,
        session: Session,
        alert: AlertRecord,
        message: str,
    ) -> None:
        contact = session.get(ContactRecord, alert.contact_id)
        if contact is None or contact.status != "verified":
            return
        delivery = AlertDeliveryRecord(
            id=str(uuid.uuid4()),
            alert_id=alert.id,
            channel="gateway_sms_follow_up",
            status="queued",
            attempts=1,
            provider_message_id=None,
            last_error=None,
            next_retry_at=None,
            created_at=self._now(),
            updated_at=self._now(),
        )
        session.add(delivery)
        try:
            delivery.provider_message_id = self.gateway.send_custody_alert(
                self._decrypt(contact.phone_encrypted),
                message,
            )
            delivery.status = "sent"
        except DeliveryError:
            delivery.status = "failed"
            delivery.last_error = "SMS provider did not accept the follow-up"

    def _alert_message(
        self,
        profile: ProfileRecord,
        alert: AlertRecord,
        session: Session,
    ) -> str:
        metadata = session.get(AlertMetadataRecord, alert.id)
        station = (
            self._decrypt(metadata.station_name_encrypted)
            if metadata and metadata.station_name_encrypted
            else None
        )
        token = self._decrypt(metadata.public_token_encrypted) if metadata else None
        is_test = bool(metadata and metadata.is_test)
        location = self._location_url(alert) or "unavailable"
        prefix = "TEST CUSTODY ALERT — NO EMERGENCY:" if is_test else "CUSTODY ALERT:"
        station_text = f" Station: {station}." if station else ""
        tracking_text = f" Updates: {self.public_base_url}/alert-status/{token}." if token else ""
        return (
            f"{prefix} {profile.full_name} says they are being arrested or held "
            f"in police custody and need help reaching a lawyer. Last known location: "
            f"{location}.{station_text} Alert time: "
            f"{self._aware(alert.triggered_at).isoformat()}.{tracking_text}"
        )

    def _location_url(self, alert: AlertRecord) -> str | None:
        if alert.latitude_encrypted is None or alert.longitude_encrypted is None:
            return None
        latitude = self._decrypt_or_none(alert.latitude_encrypted)
        longitude = self._decrypt_or_none(alert.longitude_encrypted)
        return (
            f"https://maps.google.com/?q={latitude},{longitude}"
            if latitude is not None and longitude is not None
            else None
        )

    @staticmethod
    def _owned_alert(session: Session, user_id: str, alert_id: str) -> AlertRecord:
        alert = session.get(AlertRecord, alert_id)
        if alert is None or alert.user_id != user_id:
            raise AccountError("alert not found")
        return alert

    def _new_verification(
        self,
        session: Session,
        subject_id: str,
        purpose: str,
        *,
        ttl: timedelta = TOKEN_TTL,
    ) -> str:
        token = secrets.token_urlsafe(32)
        session.add(
            VerificationRecord(
                id=str(uuid.uuid4()),
                subject_id=subject_id,
                purpose=purpose,
                token_hash=self._token_hash(token),
                expires_at=self._now() + ttl,
                used_at=None,
            )
        )
        return token

    def _consume_verification(self, session: Session, token: str, purpose: str) -> VerificationRecord:
        record = session.scalar(
            select(VerificationRecord).where(
                VerificationRecord.token_hash == self._token_hash(token),
                VerificationRecord.purpose == purpose,
            )
        )
        now = self._now()
        if record is None or record.used_at is not None or self._aware(record.expires_at) < now:
            raise AccountError("invalid or expired verification token")
        record.used_at = now
        return record

    def _access_token(self, user_id: str) -> str:
        now = self._now()
        return jwt.encode(
            {"sub": user_id, "iat": now, "exp": now + ACCESS_TTL},
            self.jwt_secret,
            algorithm="HS256",
        )

    def _encrypt(self, value: str) -> str:
        return self.cipher.encrypt(value.encode()).decode()

    def _decrypt(self, value: str) -> str:
        return self.cipher.decrypt(value.encode()).decode()

    def _decrypt_or_none(self, value: str) -> str | None:
        try:
            return self._decrypt(value)
        except InvalidToken:
            # A rotated local development key must not lock the user out.
            # The missing sensitive field is collected again under the new key.
            return None

    @staticmethod
    def _token_hash(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    @staticmethod
    def _now() -> datetime:
        return datetime.now(UTC)

    @staticmethod
    def _aware(value: datetime) -> datetime:
        return value.replace(tzinfo=UTC) if value.tzinfo is None else value

    def _contact_dict(self, contact: ContactRecord) -> dict:
        with self.sessions() as session:
            return {
                "id": contact.id,
                "name": contact.name,
                "phone": self._decrypt(contact.phone_encrypted),
                "status": contact.status,
                **self._contact_channel_dict(session, contact.id),
            }

    def _contact_channel_dict(self, session: Session, contact_id: str) -> dict:
        channel = session.get(ContactChannelRecord, contact_id)
        if channel is None:
            return {"email": None, "channels": ["sms"]}
        enabled = ["sms"]
        if channel.whatsapp_enabled:
            enabled.append("whatsapp")
        if channel.email_enabled:
            enabled.append("email")
        if channel.push_enabled:
            enabled.append("push")
        return {
            "email": (self._decrypt_or_none(channel.email_encrypted) if channel.email_encrypted else None),
            "channels": enabled,
        }

    def _alert_dict(self, session: Session, alert: AlertRecord) -> dict:
        deliveries = session.scalars(
            select(AlertDeliveryRecord)
            .where(AlertDeliveryRecord.alert_id == alert.id)
            .order_by(AlertDeliveryRecord.created_at)
        ).all()
        metadata = session.get(AlertMetadataRecord, alert.id)
        contact = session.get(ContactRecord, alert.contact_id)
        station = (
            self._decrypt_or_none(metadata.station_name_encrypted)
            if metadata and metadata.station_name_encrypted
            else None
        )
        tracking_url = (
            f"{self.public_base_url}/alert-status/" f"{self._decrypt(metadata.public_token_encrypted)}"
            if metadata
            else None
        )
        return {
            "id": alert.id,
            "contact_id": alert.contact_id,
            "contact_name": contact.name if contact else None,
            "status": alert.status,
            "triggered_at": alert.triggered_at,
            "location_shared": alert.latitude_encrypted is not None,
            "station_name": station,
            "is_test": bool(metadata and metadata.is_test),
            "tracking_url": tracking_url,
            "deliveries": [
                {
                    "channel": delivery.channel,
                    "status": delivery.status,
                    "attempts": delivery.attempts,
                    "updated_at": delivery.updated_at,
                }
                for delivery in deliveries
            ],
        }


if __name__ == "__main__":
    gateway = DevelopmentGateway()
    service = AccountService("sqlite+pysqlite:///:memory:", secret="test-secret", gateway=gateway)
    token = service.register("person@example.com", "a-long-test-password")
    assert token
    service.verify_email(token)
    access = service.login("person@example.com", "a-long-test-password")
    user_id = service.authenticate(access)
    service.update_profile(user_id, "Test Person", "+2348012345678")
    contact, contact_token = service.create_contact(user_id, "Trusted Person", "+2348098765432")
    service.verify_contact(contact_token)
    alert, duplicate = service.create_alert(user_id, contact["id"], "unique-alert-key", None, None, None)
    assert alert["status"] == "sent" and duplicate is False
    _, duplicate = service.create_alert(user_id, contact["id"], "unique-alert-key", None, None, None)
    assert duplicate is True and len(gateway.alerts) == 1
    print("All tests passed!")
