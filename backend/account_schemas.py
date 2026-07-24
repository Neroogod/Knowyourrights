"""API schemas for accounts, emergency contacts, and custody alerts."""

from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=12, max_length=128)


class RegisterResponse(BaseModel):
    message: str
    development_verification_token: str | None = None
    account_exists: bool = False


class ResendVerificationRequest(BaseModel):
    email: EmailStr


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ForgotPasswordResponse(BaseModel):
    message: str
    development_reset_token: str | None = None


class ResetPasswordRequest(BaseModel):
    token: str = Field(min_length=20, max_length=500)
    password: str = Field(min_length=12, max_length=128)


class VerifyTokenRequest(BaseModel):
    token: str = Field(min_length=20, max_length=500)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"


class DeviceSessionResponse(BaseModel):
    session_id: str
    device_name: str
    first_seen_at: datetime
    last_seen_at: datetime
    current: bool = False
    revoked: bool = False


class RoleUpdate(BaseModel):
    role: str = Field(pattern=r"^(reader|contributor|reviewer|administrator)$")


class DeleteAccountRequest(BaseModel):
    confirmation: str = Field(pattern=r"^DELETE$")


class ProfileUpdate(BaseModel):
    full_name: str = Field(min_length=2, max_length=120)
    phone: str = Field(pattern=r"^\+?[0-9]{8,15}$")


class ProfileResponse(BaseModel):
    email: EmailStr
    email_verified: bool
    full_name: str | None
    phone: str | None
    onboarding_complete: bool


class ContactCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    phone: str = Field(pattern=r"^\+?[0-9]{8,15}$")
    email: EmailStr | None = None
    channels: list[str] = Field(default_factory=lambda: ["sms"], max_length=4)
    push_token: str | None = Field(default=None, max_length=900)


class ContactResponse(BaseModel):
    id: str
    name: str
    phone: str
    status: str
    email: EmailStr | None = None
    channels: list[str] = Field(default_factory=lambda: ["sms"])
    development_verification_token: str | None = None


class AlertCreate(BaseModel):
    contact_id: str
    idempotency_key: str = Field(min_length=8, max_length=100)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    accuracy: float | None = Field(default=None, ge=0)
    station_name: str | None = Field(default=None, max_length=160)
    is_test: bool = False


class AlertDeliveryResponse(BaseModel):
    channel: str
    status: str
    attempts: int
    updated_at: datetime


class AlertResponse(BaseModel):
    id: str
    contact_id: str | None = None
    contact_name: str | None = None
    status: str
    triggered_at: datetime
    location_shared: bool
    duplicate: bool = False
    station_name: str | None = None
    is_test: bool = False
    tracking_url: str | None = None
    deliveries: list[AlertDeliveryResponse] = Field(default_factory=list)


class DeliveryCallback(BaseModel):
    provider_message_id: str = Field(min_length=1, max_length=120)
    status: str = Field(pattern=r"^(queued|sent|delivered|failed)$")
    provider_event_id: str | None = Field(default=None, min_length=1, max_length=200)


class CheckInCreate(BaseModel):
    minutes: int = Field(ge=1, le=1440)
    station_name: str | None = Field(default=None, max_length=160)


class CheckInResponse(BaseModel):
    id: str
    status: str
    due_at: datetime
    created_at: datetime
