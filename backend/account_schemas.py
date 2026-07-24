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


class UserSyncItem(BaseModel):
    kind: str = Field(pattern=r"^(saved|draft|reading_list|preference|history)$")
    item_id: str = Field(min_length=1, max_length=160)
    payload: dict = Field(default_factory=dict)
    deleted: bool = False
    updated_at: datetime


class UserSyncRequest(BaseModel):
    items: list[UserSyncItem] = Field(default_factory=list, max_length=250)


class UserSyncResponse(BaseModel):
    items: list[UserSyncItem]
    server_time: datetime


class AIReviewResponse(BaseModel):
    id: str
    corpus: str
    jurisdiction: str
    response: dict
    created_at: datetime


class AIReviewSubmit(BaseModel):
    verdict: str = Field(pattern=r"^(pass|citation_error|unsafe|incorrect|other)$")
    notes: str | None = Field(default=None, max_length=4000)


class ContributionSubmit(BaseModel):
    """A contributor's submission entering the draft -> community -> verified pipeline."""

    content_type: str = Field(pattern=r"^(topic|scenario|obligation|checklist|case|interpretation)$")
    title: str = Field(min_length=3, max_length=300)
    payload: dict = Field(default_factory=dict)


class ReviewDecisionSubmit(BaseModel):
    """A reviewer's ruling. Notes are mandatory unless the decision is `approve`."""

    decision: str = Field(pattern=r"^(approve|reject|changes)$")
    notes: str | None = Field(default=None, max_length=4000)


class ErrorReportSubmit(BaseModel):
    """Report-an-error, available on every content and answer surface."""

    target_type: str = Field(min_length=2, max_length=24)
    target_id: str = Field(min_length=1, max_length=120)
    message: str = Field(min_length=3, max_length=4000)


class ErrorReportResolve(BaseModel):
    status: str = Field(pattern=r"^(triaged|resolved|dismissed)$")
    resolution: str | None = Field(default=None, max_length=4000)


class ReadingListUpsert(BaseModel):
    """A named list of cases a student is working through."""

    id: str = Field(min_length=1, max_length=120)
    name: str = Field(min_length=1, max_length=160)
    case_ids: list[str] = Field(default_factory=list, max_length=500)


class StudentPreferences(BaseModel):
    """Client settings that must survive a reinstall."""

    law_student_mode: bool = False


class InterpretationSubmit(BaseModel):
    """A student's own commentary on a case, entering the review pipeline."""

    kind: str = Field(pattern=r"^(ratio|commentary|significance)$")
    body: str = Field(min_length=40, max_length=8000)
    citations: list[dict] = Field(default_factory=list)


class CaseDigestSubmit(BaseModel):
    """A student-authored case digest. Must be their own words, never report text."""

    name: str = Field(min_length=3, max_length=300)
    court: str = Field(min_length=2, max_length=160)
    year: int = Field(ge=1900, le=2100)
    area_of_law: str = Field(min_length=2, max_length=80)
    summary: str = Field(min_length=20, max_length=2000)
    facts: str = Field(min_length=20, max_length=8000)
    issues: list[str] = Field(min_length=1, max_length=20)
    holding: str = Field(min_length=10, max_length=4000)
    ratio: str = Field(min_length=10, max_length=4000)
    report_citation: str | None = Field(default=None, max_length=300)
    citations: list[dict] = Field(default_factory=list)


class DirectoryContribution(BaseModel):
    """A community-submitted directory entry or a correction to an existing one."""

    name: str = Field(min_length=2, max_length=200)
    entry_type: str = Field(pattern=r"^(legal_aid|ngo|lawyer|emergency)$")
    state: str | None = Field(default=None, max_length=80)
    lga: str | None = Field(default=None, max_length=80)
    phone: str | None = Field(default=None, max_length=40)
    email: str | None = Field(default=None, max_length=200)
    address: str | None = Field(default=None, max_length=400)
    specialty: list[str] = Field(default_factory=list, max_length=10)
    url: str | None = Field(default=None, max_length=300)
    corrects_id: str | None = Field(default=None, max_length=120)  # set when fixing an entry


class CheckoutRequest(BaseModel):
    """Start a payment for a plan."""

    plan: str = Field(pattern=r"^(premium|student|team)$")
