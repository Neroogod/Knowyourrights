"""Persistent account, consent, and custody-alert service."""

import base64
import hashlib
import os
import secrets
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from cryptography.fernet import Fernet
from sqlalchemy import DateTime, Float, ForeignKey, String, UniqueConstraint, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker
from sqlalchemy.pool import StaticPool

from backend.delivery import DeliveryError, DeliveryGateway, DevelopmentGateway

DEFAULT_DATABASE_URL = f"sqlite:///{Path(__file__).resolve().parents[1] / 'data' / 'accounts.db'}"
TOKEN_TTL = timedelta(minutes=60)
ACCESS_TTL = timedelta(hours=1)
GENERIC_REGISTER_MESSAGE = "If this address can be registered, a verification email has been sent."


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
            return {
                "email": user.email,
                "email_verified": user.email_verified_at is not None,
                "full_name": profile.full_name if profile else None,
                "phone": self._decrypt(profile.phone_encrypted) if profile else None,
                "onboarding_complete": profile is not None,
            }

    def create_contact(self, user_id: str, name: str, phone: str) -> tuple[dict, str]:
        with self.sessions.begin() as session:
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
            token = self._new_verification(session, contact.id, "contact")
        self.gateway.send_contact_verification(phone, contact.name, token)
        return self._contact_dict(contact), token

    def verify_contact(self, token: str) -> None:
        with self.sessions.begin() as session:
            record = self._consume_verification(session, token, "contact")
            contact = session.get(ContactRecord, record.subject_id)
            if contact is None or contact.status != "pending":
                raise AccountError("invalid verification token")
            contact.status = "verified"
            contact.verified_at = self._now()

    def contacts(self, user_id: str) -> list[dict]:
        with self.sessions() as session:
            rows = session.scalars(select(ContactRecord).where(ContactRecord.user_id == user_id)).all()
            return [self._contact_dict(row) for row in rows]

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
    ) -> tuple[dict, bool]:
        with self.sessions.begin() as session:
            existing = session.scalar(
                select(AlertRecord).where(
                    AlertRecord.user_id == user_id,
                    AlertRecord.idempotency_key == idempotency_key,
                )
            )
            if existing:
                return self._alert_dict(existing), True
            profile = session.get(ProfileRecord, user_id)
            contact = session.get(ContactRecord, contact_id)
            if profile is None:
                raise AccountError("complete your profile before sending an alert")
            if contact is None or contact.user_id != user_id or contact.status != "verified":
                raise AccountError("a verified emergency contact is required")
            location = (
                f"https://maps.google.com/?q={latitude},{longitude}"
                if latitude is not None and longitude is not None
                else "unavailable"
            )
            message = (
                f"CUSTODY ALERT: {profile.full_name} says they are being arrested or held "
                f"in police custody and need help reaching a lawyer. Last known location: "
                f"{location}. Alert time: {self._now().isoformat()}."
            )
            alert = AlertRecord(
                id=str(uuid.uuid4()),
                user_id=user_id,
                contact_id=contact.id,
                idempotency_key=idempotency_key,
                latitude_encrypted=self._encrypt(str(latitude)) if latitude is not None else None,
                longitude_encrypted=self._encrypt(str(longitude)) if longitude is not None else None,
                accuracy=accuracy,
                status="accepted",
                provider_message_id=None,
                triggered_at=self._now(),
            )
            session.add(alert)
            session.flush()
            try:
                provider_id = self.gateway.send_custody_alert(
                    self._decrypt(contact.phone_encrypted), message
                )
                alert.provider_message_id = provider_id
                alert.status = "sent"
            except DeliveryError:
                alert.status = "failed"
            return self._alert_dict(alert), False

    def get_alert(self, user_id: str, alert_id: str) -> dict:
        with self.sessions() as session:
            alert = session.get(AlertRecord, alert_id)
            if alert is None or alert.user_id != user_id:
                raise AccountError("alert not found")
            return self._alert_dict(alert)

    def _new_verification(self, session: Session, subject_id: str, purpose: str) -> str:
        token = secrets.token_urlsafe(32)
        session.add(
            VerificationRecord(
                id=str(uuid.uuid4()),
                subject_id=subject_id,
                purpose=purpose,
                token_hash=self._token_hash(token),
                expires_at=self._now() + TOKEN_TTL,
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
        return {
            "id": contact.id,
            "name": contact.name,
            "phone": self._decrypt(contact.phone_encrypted),
            "status": contact.status,
        }

    @staticmethod
    def _alert_dict(alert: AlertRecord) -> dict:
        return {
            "id": alert.id,
            "status": alert.status,
            "triggered_at": alert.triggered_at,
            "location_shared": alert.latitude_encrypted is not None,
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
