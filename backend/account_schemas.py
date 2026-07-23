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
    token_type: str = "bearer"


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


class ContactResponse(BaseModel):
    id: str
    name: str
    phone: str
    status: str
    development_verification_token: str | None = None


class AlertCreate(BaseModel):
    contact_id: str
    idempotency_key: str = Field(min_length=8, max_length=100)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    accuracy: float | None = Field(default=None, ge=0)


class AlertResponse(BaseModel):
    id: str
    status: str
    triggered_at: datetime
    location_shared: bool
    duplicate: bool = False
