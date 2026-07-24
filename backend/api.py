"""KnowYourRights HTTP API (FastAPI).

Serves verified rights content, emergency scenarios, a directory, search, and a
gated, grounded Q&A endpoint. Reference/scenario/directory data is designed to be
cached by the app for offline use; /ask requires connectivity.
"""

import asyncio
import base64
import hashlib
import hmac
import html
import json
import os
import urllib.error
import urllib.request
from contextlib import asynccontextmanager, suppress
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated
from urllib.parse import parse_qs

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import (
    FileResponse,
    HTMLResponse,
    JSONResponse,
    RedirectResponse,
    Response,
    StreamingResponse,
)
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles

from backend.account_schemas import (
    AIReviewResponse,
    AIReviewSubmit,
    AlertCreate,
    AlertResponse,
    CheckInCreate,
    CheckInResponse,
    ContactCreate,
    ContactResponse,
    DeleteAccountRequest,
    DeliveryCallback,
    DeviceSessionResponse,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    ProfileResponse,
    ProfileUpdate,
    RegisterRequest,
    RegisterResponse,
    ResendVerificationRequest,
    ResetPasswordRequest,
    RoleUpdate,
    TokenResponse,
    UserSyncRequest,
    UserSyncResponse,
    VerifyTokenRequest,
)
from backend.accounts import (
    GENERIC_REGISTER_MESSAGE,
    AccountError,
    AccountService,
)
from backend.ai_ops import AIProductionGate, AIRequestContext
from backend.content_store import ContentStore
from backend.content_sync import ContentSigner, signed_pack
from backend.delivery import gateway_from_environment
from backend.managed_auth import AuthIdentity, SupabaseTokenVerifier
from backend.schemas import (
    AskRequest,
    AskResponse,
    CaseBrief,
    CompanyChecklist,
    ContentPack,
    DirectoryEntry,
    Obligation,
    Scenario,
    Topic,
)

WEB_DIR = Path(__file__).resolve().parents[1] / "web"


def create_app(
    store: ContentStore | None = None,
    account_service: AccountService | None = None,
) -> FastAPI:
    """Application factory so tests can inject a store without touching disk."""
    development_mode = os.getenv("KYR_DEVELOPMENT_MODE") == "1"
    resolved_store = store or ContentStore.from_environment()
    accounts = account_service or AccountService(gateway=gateway_from_environment(development_mode))
    managed_auth = SupabaseTokenVerifier()

    async def alert_retry_worker() -> None:
        while True:
            await asyncio.sleep(15)
            await asyncio.to_thread(accounts.retry_due_alerts)
            await asyncio.to_thread(accounts.purge_expired_locations)
            await asyncio.to_thread(accounts.process_due_check_ins)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.alert_retry_task = asyncio.create_task(alert_retry_worker())
        try:
            yield
        finally:
            app.state.alert_retry_task.cancel()
            with suppress(asyncio.CancelledError):
                await app.state.alert_retry_task

    app = FastAPI(
        title="KnowYourRights API",
        version="0.1.0",
        lifespan=lifespan,
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )
    bearer = HTTPBearer(auto_error=False)
    app.state.store = resolved_store
    app.state.accounts = accounts
    app.state.content_signer = ContentSigner.from_environment()
    app.state.ai_gate = AIProductionGate(accounts, resolved_store.version)

    def request_ip(request: Request) -> str:
        forwarded = request.headers.get("x-forwarded-for", "").split(",")[0].strip()
        return forwarded or (request.client.host if request.client else "unknown")

    def limit_request(request: Request, bucket: str, limit: int, window: int) -> None:
        device = request.headers.get("x-device-id", "unknown")[:128]
        for key in (
            f"{bucket}:ip:{request_ip(request)}",
            f"{bucket}:device:{device}",
        ):
            if not accounts.check_rate_limit(key, limit, window):
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many requests. Please wait and try again.",
                    headers={"Retry-After": str(window)},
                )

    def current_user(
        request: Request,
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    ) -> str:
        if credentials is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="authentication required")
        try:
            if managed_auth.enabled:
                identity = managed_auth.verify(credentials.credentials)
                accounts.ensure_managed_user(identity.user_id, identity.email)
                if identity.session_id and not accounts.session_allowed(
                    identity.user_id, identity.session_id
                ):
                    raise AccountError("this device session has been revoked")
                request.state.auth_identity = identity
                device_id = request.headers.get("x-device-id")
                if identity.session_id and device_id:
                    accounts.record_device(
                        identity.user_id,
                        identity.session_id,
                        device_id,
                        request.headers.get("x-device-name", "Unknown device"),
                    )
                return identity.user_id
            user_id = accounts.authenticate(credentials.credentials)
            request.state.auth_identity = AuthIdentity(
                user_id=user_id,
                email=accounts.profile(user_id)["email"],
                session_id=None,
                role=accounts.role(user_id),
                authenticated_at=datetime.now(UTC),
            )
            return user_id
        except AccountError as error:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(error)) from error

    def recent_user(
        request: Request,
        user_id: Annotated[str, Depends(current_user)],
    ) -> str:
        identity: AuthIdentity = request.state.auth_identity
        if not identity.recently_authenticated:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Please reauthenticate before making this sensitive change.",
            )
        return user_id

    def optional_user(
        request: Request,
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    ) -> str | None:
        if credentials is None:
            return None
        return current_user(request, credentials)

    def ai_context(
        request: Request,
        user_id: str | None,
        corpus: str,
        jurisdiction: str,
    ) -> AIRequestContext:
        if jurisdiction != "NG-Federal":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This AI corpus currently supports NG-Federal law only.",
            )
        raw_identifier = (
            f"user:{user_id}"
            if user_id
            else (
                f"anonymous:{request_ip(request)}:" f"{request.headers.get('x-device-id', 'unknown')[:128]}"
            )
        )
        return AIRequestContext(
            corpus=corpus,
            jurisdiction=jurisdiction,
            privacy_id=app.state.ai_gate.privacy_id(raw_identifier),
            user_id=user_id,
        )

    def gated_answer(
        request: Request,
        body: AskRequest,
        user_id: str | None,
        *,
        corpus: str,
        jurisdiction: str,
    ) -> tuple[AskResponse, bool, str]:
        limit_request(request, f"ai:{corpus}", 30, 3600)
        answerers = {
            "rights": resolved_store.ask,
            "company": resolved_store.ask_company,
            "students": resolved_store.ask_students,
        }
        try:
            return app.state.ai_gate.answer(
                body.question,
                ai_context(request, user_id, corpus, jurisdiction),
                answerers[corpus],
            )
        except PermissionError as error:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=str(error),
                headers={"Retry-After": "86400"},
            ) from error

    def account_error(error: AccountError) -> HTTPException:
        return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    @app.get("/v1/health")
    def health() -> dict:
        return {"status": "ok", "content_version": resolved_store.version}

    @app.get("/v1/auth/config")
    def auth_config() -> dict:
        return {
            "provider": "supabase" if managed_auth.enabled else "legacy",
            "supabase_url": os.getenv("SUPABASE_URL") if managed_auth.enabled else None,
            "supabase_publishable_key": (
                os.getenv("SUPABASE_PUBLISHABLE_KEY") if managed_auth.enabled else None
            ),
        }

    @app.post("/v1/auth/register", response_model=RegisterResponse)
    def register(request: RegisterRequest, http_request: Request) -> RegisterResponse:
        limit_request(http_request, "register", 5, 3600)
        account_exists = accounts.email_exists(str(request.email))
        token = accounts.register(str(request.email), request.password)
        return RegisterResponse(
            message=GENERIC_REGISTER_MESSAGE,
            development_verification_token=token if development_mode else None,
            account_exists=account_exists,
        )

    @app.post("/v1/auth/verify-email")
    def verify_email(request: VerifyTokenRequest) -> dict:
        try:
            accounts.verify_email(request.token)
        except AccountError as error:
            raise account_error(error) from error
        return {"verified": True}

    @app.get("/verify-email", include_in_schema=False)
    def verify_email_link(token: str) -> RedirectResponse:
        try:
            accounts.verify_email(token)
        except AccountError as error:
            raise account_error(error) from error
        return RedirectResponse("/?verified=1", status_code=303)

    @app.post("/v1/auth/resend-verification", response_model=RegisterResponse)
    def resend_verification(request: ResendVerificationRequest, http_request: Request) -> RegisterResponse:
        limit_request(http_request, "resend", 4, 3600)
        token = accounts.resend_email_verification(str(request.email))
        return RegisterResponse(
            message=GENERIC_REGISTER_MESSAGE,
            development_verification_token=token if development_mode else None,
            account_exists=accounts.email_exists(str(request.email)),
        )

    @app.post("/v1/auth/login", response_model=TokenResponse)
    def login(request: LoginRequest, http_request: Request) -> TokenResponse:
        limit_request(http_request, "login", 10, 900)
        if managed_auth.enabled:
            raise HTTPException(
                status_code=status.HTTP_410_GONE,
                detail="Use Supabase Auth from the application client.",
            )
        try:
            token = accounts.login(str(request.email), request.password)
        except AccountError as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="invalid email or password",
            ) from error
        return TokenResponse(access_token=token)

    @app.post("/v1/auth/forgot-password", response_model=ForgotPasswordResponse)
    def forgot_password(request: ForgotPasswordRequest, http_request: Request) -> ForgotPasswordResponse:
        limit_request(http_request, "forgot-password", 4, 3600)
        token = accounts.request_password_reset(str(request.email))
        return ForgotPasswordResponse(
            message="If an account exists for this email, a password reset link has been sent.",
            development_reset_token=token if development_mode else None,
        )

    @app.post("/v1/auth/reset-password")
    def reset_password(request: ResetPasswordRequest, http_request: Request) -> dict:
        limit_request(http_request, "reset-password", 6, 3600)
        try:
            accounts.reset_password(request.token, request.password)
        except AccountError as error:
            raise account_error(error) from error
        return {"reset": True}

    @app.get("/v1/profile", response_model=ProfileResponse)
    def get_profile(user_id: Annotated[str, Depends(current_user)]) -> ProfileResponse:
        try:
            return ProfileResponse(**accounts.profile(user_id))
        except AccountError as error:
            raise account_error(error) from error

    @app.get("/v1/account/sessions", response_model=list[DeviceSessionResponse])
    def sessions(
        request: Request,
        user_id: Annotated[str, Depends(current_user)],
    ) -> list[DeviceSessionResponse]:
        identity: AuthIdentity = request.state.auth_identity
        return [
            DeviceSessionResponse(
                **item,
                current=item["session_id"] == identity.session_id,
            )
            for item in accounts.device_sessions(user_id)
        ]

    @app.delete("/v1/account/sessions/{session_id}")
    def revoke_session(
        session_id: str,
        request: Request,
        user_id: Annotated[str, Depends(recent_user)],
    ) -> dict:
        identity: AuthIdentity = request.state.auth_identity
        try:
            accounts.revoke_device_session(user_id, session_id, identity.session_id)
        except AccountError as error:
            raise account_error(error) from error
        return {"revoked": True}

    @app.get("/v1/account/export")
    def export_account(
        user_id: Annotated[str, Depends(recent_user)],
    ) -> dict:
        return accounts.export_account(user_id)

    @app.delete("/v1/account")
    def delete_account(
        request: DeleteAccountRequest,
        user_id: Annotated[str, Depends(recent_user)],
    ) -> dict:
        if request.confirmation != "DELETE":
            raise HTTPException(status_code=400, detail="confirmation required")
        if managed_auth.enabled:
            service_key = os.getenv("SUPABASE_SECRET_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
            project_url = os.getenv("SUPABASE_URL", "").rstrip("/")
            if not service_key:
                raise HTTPException(status_code=503, detail="account deletion is not configured")
            admin_request = urllib.request.Request(
                f"{project_url}/auth/v1/admin/users/{user_id}",
                method="DELETE",
                headers={
                    "apikey": service_key,
                    "Authorization": f"Bearer {service_key}",
                },
            )
            try:
                with urllib.request.urlopen(admin_request, timeout=10):
                    pass
            except urllib.error.HTTPError as error:
                raise HTTPException(status_code=502, detail="identity deletion failed") from error
        accounts.delete_account_data(user_id)
        return {"deleted": True}

    @app.put("/v1/admin/users/{target_user_id}/role")
    def update_role(
        target_user_id: str,
        request: RoleUpdate,
        user_id: Annotated[str, Depends(recent_user)],
    ) -> dict:
        try:
            accounts.set_role(user_id, target_user_id, request.role)
        except AccountError as error:
            raise HTTPException(status_code=403, detail=str(error)) from error
        return {"user_id": target_user_id, "role": request.role}

    @app.put("/v1/profile", response_model=ProfileResponse)
    def update_profile(
        request: ProfileUpdate,
        user_id: Annotated[str, Depends(current_user)],
    ) -> ProfileResponse:
        accounts.update_profile(user_id, request.full_name, request.phone)
        return ProfileResponse(**accounts.profile(user_id))

    @app.get("/v1/emergency-contacts", response_model=list[ContactResponse])
    def list_contacts(user_id: Annotated[str, Depends(current_user)]) -> list[ContactResponse]:
        return [ContactResponse(**contact) for contact in accounts.contacts(user_id)]

    @app.post("/v1/emergency-contacts", response_model=ContactResponse)
    def create_contact(
        request: ContactCreate,
        user_id: Annotated[str, Depends(current_user)],
    ) -> ContactResponse:
        unsupported = set(request.channels) - {"sms", "whatsapp", "email", "push"}
        if unsupported:
            raise HTTPException(status_code=400, detail="unsupported contact channel")
        try:
            contact, token = accounts.create_contact(
                user_id,
                request.name,
                request.phone,
                str(request.email) if request.email else None,
                request.channels,
                request.push_token,
            )
        except AccountError as error:
            raise account_error(error) from error
        return ContactResponse(
            **contact,
            development_verification_token=token if development_mode else None,
        )

    @app.post("/v1/emergency-contacts/verify")
    def verify_contact(request: VerifyTokenRequest) -> dict:
        try:
            accounts.verify_contact(request.token)
        except AccountError as error:
            raise account_error(error) from error
        return {"verified": True}

    @app.get("/contact-verification", response_class=HTMLResponse, include_in_schema=False)
    def verify_contact_link(token: str) -> HTMLResponse:
        try:
            accounts.verify_contact(token)
            body = "Emergency contact confirmed. You may close this page."
        except AccountError:
            body = "This confirmation link is invalid, expired, or already used."
        return HTMLResponse(
            f"<!doctype html><title>Know Your Rights</title>"
            f"<main style='font:18px system-ui;max-width:560px;margin:12vh auto;padding:24px'>"
            f"<h1>Know Your Rights</h1><p>{body}</p></main>"
        )

    @app.get("/contact-decline", response_class=HTMLResponse, include_in_schema=False)
    def decline_contact_link(token: str) -> HTMLResponse:
        try:
            accounts.decline_contact(token)
            body = "You declined this emergency-contact invitation. No alerts will be sent to you."
        except AccountError:
            body = "This decline link is invalid, expired, or already used."
        return HTMLResponse(
            f"<!doctype html><title>Emergency contact</title>"
            f"<main style='font:18px system-ui;max-width:560px;margin:12vh auto;padding:24px'>"
            f"<h1>Know Your Rights</h1><p>{body}</p></main>"
        )

    @app.get("/contact-withdraw", response_class=HTMLResponse, include_in_schema=False)
    def withdraw_contact_link(token: str) -> HTMLResponse:
        try:
            accounts.withdraw_contact(token)
            body = "Your consent was withdrawn. You will not receive further custody alerts."
        except AccountError:
            body = "This withdrawal link is invalid, expired, or already used."
        return HTMLResponse(
            f"<!doctype html><title>Emergency contact</title>"
            f"<main style='font:18px system-ui;max-width:560px;margin:12vh auto;padding:24px'>"
            f"<h1>Know Your Rights</h1><p>{body}</p></main>"
        )

    @app.delete("/v1/emergency-contacts/{contact_id}", status_code=204)
    def delete_contact(
        contact_id: str,
        user_id: Annotated[str, Depends(current_user)],
    ) -> None:
        try:
            accounts.delete_contact(user_id, contact_id)
        except AccountError as error:
            raise account_error(error) from error

    @app.post("/v1/custody-alerts", response_model=AlertResponse)
    def create_custody_alert(
        body: AlertCreate,
        request: Request,
        user_id: Annotated[str, Depends(current_user)],
    ) -> AlertResponse:
        limit_request(request, "custody-alert", 6, 3600)
        if not accounts.check_rate_limit(f"custody-alert:user:{user_id}", 6, 3600):
            raise HTTPException(status_code=429, detail="User alert limit reached.")
        if not accounts.check_rate_limit(f"custody-alert:contact:{body.contact_id}", 4, 3600):
            raise HTTPException(status_code=429, detail="Contact alert limit reached.")
        try:
            accounts.purge_expired_locations()
            alert, duplicate = accounts.create_alert(
                user_id,
                body.contact_id,
                body.idempotency_key,
                body.latitude,
                body.longitude,
                body.accuracy,
                body.station_name,
                body.is_test,
            )
        except AccountError as error:
            raise account_error(error) from error
        return AlertResponse(**alert, duplicate=duplicate)

    @app.get("/v1/custody-alerts", response_model=list[AlertResponse])
    def custody_alert_history(
        user_id: Annotated[str, Depends(current_user)],
        limit: int = Query(default=50, ge=1, le=100),
    ) -> list[AlertResponse]:
        return [AlertResponse(**item) for item in accounts.alert_history(user_id, limit)]

    @app.get("/v1/public/custody-alerts/{token}")
    def public_custody_alert(token: str) -> dict:
        try:
            return accounts.public_alert(token)
        except AccountError as error:
            raise HTTPException(status_code=404, detail=str(error)) from error

    @app.get("/alert-status/{token}", response_class=HTMLResponse, include_in_schema=False)
    def public_custody_alert_page(token: str) -> HTMLResponse:
        try:
            alert = accounts.public_alert(token)
        except AccountError:
            raise HTTPException(status_code=404, detail="Alert status not found") from None
        test_label = (
            "<p style='padding:12px;background:#fff4d6'><strong>TEST ALERT — " "NO EMERGENCY</strong></p>"
            if alert["is_test"]
            else ""
        )
        location = (
            f"<p><a href='{alert['location_url']}'>Open last known location</a></p>"
            if alert.get("location_url")
            else "<p>Location was unavailable or has been removed.</p>"
        )
        station = (
            f"<p><strong>Station:</strong> {html.escape(str(alert['station_name']))}</p>"
            if alert.get("station_name")
            else ""
        )
        safe_status = html.escape(str(alert["status"]))
        safe_sender = html.escape(str(alert["sender_name"]))
        return HTMLResponse(
            "<!doctype html><html lang='en'><meta name='viewport' content='width=device-width'>"
            "<meta name='color-scheme' content='light dark'><title>Custody Alert status</title>"
            "<style>"
            ":root{font-family:Inter,ui-sans-serif,system-ui;color:#17231d;background:#f3f2ec}"
            "*{box-sizing:border-box}body{margin:0;min-height:100vh;padding:28px 18px;"
            "background:radial-gradient(circle at 80% 0,#dceae1 0,transparent 38%),#f3f2ec}"
            "main{max-width:620px;margin:5vh auto;background:rgba(255,255,255,.78);"
            "backdrop-filter:blur(18px);border:1px solid rgba(255,255,255,.9);border-radius:28px;"
            "padding:clamp(22px,5vw,40px);box-shadow:0 24px 70px rgba(27,53,39,.13)}"
            ".brand{color:#12543a;font-size:.75rem;font-weight:850;letter-spacing:.13em;"
            "text-transform:uppercase}.status{display:inline-block;border-radius:99px;padding:6px 11px;"
            "background:#e1f1e7;color:#12543a;font-size:.75rem;font-weight:850;text-transform:uppercase}"
            "h1{font-family:Georgia,serif;font-size:clamp(2rem,8vw,3.1rem);line-height:1.02;margin:18px 0}"
            "h2{font-size:1rem;margin-top:28px}p,li{line-height:1.6;color:#526159}"
            "strong{color:#17231d}a{color:#12543a;font-weight:750}.private{border-top:1px solid #dce1dc;"
            "padding-top:16px;margin-top:28px;font-size:.78rem}ol{padding-left:22px}"
            "@media(prefers-color-scheme:dark){:root{color:#edf5ef;background:#101713}"
            "body{background:radial-gradient(circle at 80% 0,#183d2c 0,transparent 38%),#101713}"
            "main{background:rgba(24,34,28,.82);border-color:#35453b}p,li{color:#afbeb4}"
            "strong{color:#edf5ef}.private{border-color:#35453b}.status{background:#204c35;color:#bde5cd}}"
            "</style><main><div class='brand'>Know Your Rights · Nigeria</div>"
            f"<h1>Custody alert</h1>{test_label}<span class='status'>{safe_status}</span>"
            f"<p><strong>{safe_sender}</strong> shared this custody alert with you.</p>"
            f"{station}{location}<h2>What you can do now</h2>"
            "<ol><li>Call or message them to confirm where they are being held.</li>"
            "<li>Contact their lawyer or the Legal Aid Council.</li>"
            "<li>Write down names, station details, and the time of arrest.</li></ol>"
            "<p class='private'>This is a private safety link. Do not post or forward it publicly.</p>"
            "</main></html>"
        )

    @app.post("/v1/check-ins", response_model=CheckInResponse)
    def arm_check_in(
        body: CheckInCreate,
        request: Request,
        user_id: Annotated[str, Depends(current_user)],
    ) -> CheckInResponse:
        limit_request(request, "check-in", 12, 3600)
        try:
            return CheckInResponse(**accounts.arm_check_in(user_id, body.minutes, body.station_name))
        except AccountError as error:
            raise account_error(error) from error

    @app.get("/v1/check-ins/active", response_model=CheckInResponse | None)
    def active_check_in(
        user_id: Annotated[str, Depends(current_user)],
    ) -> CheckInResponse | None:
        record = accounts.active_check_in(user_id)
        return CheckInResponse(**record) if record else None

    @app.post("/v1/check-ins/{check_in_id}/safe", response_model=CheckInResponse)
    def complete_check_in(
        check_in_id: str,
        user_id: Annotated[str, Depends(current_user)],
    ) -> CheckInResponse:
        try:
            return CheckInResponse(**accounts.complete_check_in(user_id, check_in_id))
        except AccountError as error:
            raise account_error(error) from error

    @app.get("/v1/custody-alerts/{alert_id}", response_model=AlertResponse)
    def get_custody_alert(
        alert_id: str,
        user_id: Annotated[str, Depends(current_user)],
    ) -> AlertResponse:
        try:
            return AlertResponse(**accounts.get_alert(user_id, alert_id))
        except AccountError as error:
            raise account_error(error) from error

    @app.post("/v1/custody-alerts/{alert_id}/cancel", response_model=AlertResponse)
    def cancel_custody_alert(
        alert_id: str,
        user_id: Annotated[str, Depends(current_user)],
    ) -> AlertResponse:
        try:
            return AlertResponse(**accounts.cancel_alert(user_id, alert_id))
        except AccountError as error:
            raise account_error(error) from error

    @app.post("/v1/custody-alerts/{alert_id}/resolve", response_model=AlertResponse)
    def resolve_custody_alert(
        alert_id: str,
        user_id: Annotated[str, Depends(current_user)],
    ) -> AlertResponse:
        try:
            return AlertResponse(**accounts.resolve_alert(user_id, alert_id))
        except AccountError as error:
            raise account_error(error) from error

    @app.post("/v1/custody-alerts/{alert_id}/retry", response_model=AlertResponse)
    def retry_custody_alert(
        alert_id: str,
        user_id: Annotated[str, Depends(current_user)],
    ) -> AlertResponse:
        try:
            return AlertResponse(**accounts.retry_alert(user_id, alert_id))
        except AccountError as error:
            raise account_error(error) from error

    @app.post("/v1/custody-alerts/delivery-callback", response_model=AlertResponse)
    def custody_alert_delivery_callback(
        request: DeliveryCallback,
        webhook_secret: Annotated[str | None, Header(alias="X-KYR-Webhook-Secret")] = None,
    ) -> AlertResponse:
        configured = os.getenv("KYR_DELIVERY_WEBHOOK_SECRET")
        if not configured or not webhook_secret or not hmac.compare_digest(configured, webhook_secret):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="invalid webhook signature",
            )
        try:
            event_id = request.provider_event_id or (f"{request.provider_message_id}:{request.status}")
            return AlertResponse(
                **accounts.process_delivery_callback(
                    event_id,
                    request.provider_message_id,
                    request.status,
                )
            )
        except AccountError as error:
            raise account_error(error) from error

    @app.post(
        "/v1/custody-alerts/twilio-callback",
        response_model=AlertResponse,
        include_in_schema=False,
    )
    async def custody_alert_twilio_callback(request: Request) -> AlertResponse:
        auth_token = os.getenv("TWILIO_AUTH_TOKEN")
        public_base_url = os.getenv("KYR_PUBLIC_BASE_URL", "").rstrip("/")
        signature = request.headers.get("X-Twilio-Signature", "")
        raw_body = await request.body()
        params = {
            key: values[0] for key, values in parse_qs(raw_body.decode(), keep_blank_values=True).items()
        }
        callback_url = f"{public_base_url}/v1/custody-alerts/twilio-callback"
        signed = callback_url + "".join(f"{key}{value}" for key, value in sorted(params.items()))
        expected = (
            base64.b64encode(
                hmac.new(
                    auth_token.encode(),
                    signed.encode(),
                    hashlib.sha1,
                ).digest()
            ).decode()
            if auth_token and public_base_url
            else ""
        )
        if not signature or not expected or not hmac.compare_digest(signature, expected):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="invalid Twilio signature",
            )
        provider_status = params.get("MessageStatus", "")
        mapped_status = {
            "accepted": "queued",
            "queued": "queued",
            "sending": "queued",
            "sent": "sent",
            "delivered": "delivered",
            "undelivered": "failed",
            "failed": "failed",
        }.get(provider_status)
        message_id = params.get("MessageSid")
        if mapped_status is None or not message_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="invalid delivery callback",
            )
        try:
            event_id = f"twilio:{message_id}:{provider_status}"
            return AlertResponse(
                **accounts.process_delivery_callback(
                    event_id,
                    message_id,
                    mapped_status,
                )
            )
        except AccountError as error:
            raise account_error(error) from error

    @app.get("/v1/topics", response_model=list[Topic])
    def list_topics(category: str | None = Query(default=None)) -> list[Topic]:
        return resolved_store.list_topics(category=category)

    @app.get("/v1/topics/{topic_id}", response_model=Topic)
    def get_topic(topic_id: str) -> Topic:
        topic = resolved_store.get_topic(topic_id)
        if topic is None:
            raise HTTPException(status_code=404, detail="topic not found")
        return topic

    @app.get("/v1/scenarios", response_model=list[Scenario])
    def list_scenarios() -> list[Scenario]:
        return resolved_store.list_scenarios()

    @app.get("/v1/scenarios/{scenario_id}", response_model=Scenario)
    def get_scenario(scenario_id: str) -> Scenario:
        scenario = resolved_store.get_scenario(scenario_id)
        if scenario is None:
            raise HTTPException(status_code=404, detail="scenario not found")
        return scenario

    @app.get("/v1/directory", response_model=list[DirectoryEntry])
    def list_directory() -> list[DirectoryEntry]:
        return resolved_store.list_directory()

    @app.get("/v1/company/obligations", response_model=list[Obligation])
    def list_obligations() -> list[Obligation]:
        return resolved_store.list_obligations()

    @app.get("/v1/company/obligations/{obligation_id}", response_model=Obligation)
    def get_obligation(obligation_id: str) -> Obligation:
        obligation = resolved_store.get_obligation(obligation_id)
        if obligation is None:
            raise HTTPException(status_code=404, detail="obligation not found")
        return obligation

    @app.get("/v1/company/checklists", response_model=list[CompanyChecklist])
    def list_company_checklists() -> list[CompanyChecklist]:
        return resolved_store.list_company_checklists()

    @app.post("/v1/company/ask", response_model=AskResponse)
    def ask_company(
        body: AskRequest,
        request: Request,
        response: Response,
        user_id: Annotated[str | None, Depends(optional_user)],
        jurisdiction: str = Query(default="NG-Federal"),
    ) -> AskResponse:
        answer, cache_hit, event_id = gated_answer(
            request,
            body,
            user_id,
            corpus="company",
            jurisdiction=jurisdiction,
        )
        response.headers["X-AI-Cache"] = "hit" if cache_hit else "miss"
        response.headers["X-AI-Event-ID"] = event_id
        return answer

    @app.get("/v1/students/cases", response_model=list[CaseBrief])
    def list_cases(
        area_of_law: str | None = Query(default=None),
        year: int | None = Query(default=None),
    ) -> list[CaseBrief]:
        return resolved_store.list_cases(area_of_law=area_of_law, year=year)

    @app.get("/v1/students/cases/{case_id}", response_model=CaseBrief)
    def get_case(case_id: str) -> CaseBrief:
        case = resolved_store.get_case(case_id)
        if case is None:
            raise HTTPException(status_code=404, detail="case not found")
        return case

    @app.post("/v1/students/ask", response_model=AskResponse)
    def ask_students(
        body: AskRequest,
        request: Request,
        response: Response,
        user_id: Annotated[str | None, Depends(optional_user)],
        jurisdiction: str = Query(default="NG-Federal"),
    ) -> AskResponse:
        answer, cache_hit, event_id = gated_answer(
            request,
            body,
            user_id,
            corpus="students",
            jurisdiction=jurisdiction,
        )
        response.headers["X-AI-Cache"] = "hit" if cache_hit else "miss"
        response.headers["X-AI-Event-ID"] = event_id
        return answer

    @app.get("/v1/search", response_model=list[Topic])
    def search(q: str = Query(min_length=1)) -> list[Topic]:
        return resolved_store.search_topics(q)

    @app.post("/v1/ask", response_model=AskResponse)
    def ask(
        body: AskRequest,
        request: Request,
        response: Response,
        user_id: Annotated[str | None, Depends(optional_user)],
        jurisdiction: str = Query(default="NG-Federal"),
    ) -> AskResponse:
        answer, cache_hit, event_id = gated_answer(
            request,
            body,
            user_id,
            corpus="rights",
            jurisdiction=jurisdiction,
        )
        response.headers["X-AI-Cache"] = "hit" if cache_hit else "miss"
        response.headers["X-AI-Event-ID"] = event_id
        return answer

    @app.post("/v1/ask/stream")
    def ask_stream(
        body: AskRequest,
        request: Request,
        user_id: Annotated[str | None, Depends(optional_user)],
        jurisdiction: str = Query(default="NG-Federal"),
    ) -> StreamingResponse:
        answer, cache_hit, event_id = gated_answer(
            request,
            body,
            user_id,
            corpus="rights",
            jurisdiction=jurisdiction,
        )

        def events():
            yield f"event: metadata\ndata: {json.dumps({'event_id': event_id, 'cache_hit': cache_hit})}\n\n"
            words = answer.answer.split()
            for start in range(0, len(words), 18):
                yield (
                    "event: answer_delta\ndata: "
                    + json.dumps({"text": " ".join(words[start : start + 18]) + " "})
                    + "\n\n"
                )
            yield ("event: completed\ndata: " + answer.model_dump_json() + "\n\n")

        return StreamingResponse(
            events(),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
        )

    @app.get("/v1/admin/ai-reviews", response_model=list[AIReviewResponse])
    def pending_ai_reviews(
        user_id: Annotated[str, Depends(current_user)],
        limit: int = Query(default=50, ge=1, le=200),
    ) -> list[dict]:
        if accounts.role(user_id) not in {"reviewer", "administrator"}:
            raise HTTPException(status_code=403, detail="reviewer role required")
        return accounts.pending_ai_reviews(limit)

    @app.post("/v1/admin/ai-reviews/{event_id}", status_code=204)
    def submit_ai_review(
        event_id: str,
        body: AIReviewSubmit,
        user_id: Annotated[str, Depends(current_user)],
    ) -> Response:
        if accounts.role(user_id) not in {"reviewer", "administrator"}:
            raise HTTPException(status_code=403, detail="reviewer role required")
        try:
            accounts.review_ai_answer(event_id, user_id, body.verdict, body.notes)
        except AccountError as error:
            raise account_error(error) from error
        return Response(status_code=204)

    @app.get("/v1/content-pack", response_model=ContentPack)
    def content_pack() -> ContentPack:
        return resolved_store._pack  # full pack for offline caching

    @app.get("/v1/content-packs/config")
    def content_pack_config() -> dict:
        signer: ContentSigner = app.state.content_signer
        return {
            "algorithm": "Ed25519",
            "key_id": signer.key_id,
            "public_key": signer.public_key,
            "layers": ["rights", "students", "company"],
            "jurisdictions": ["NG-Federal"],
        }

    @app.get("/v1/content-packs/{layer}")
    def content_pack_delta(
        layer: str,
        request: Request,
        since: int = Query(default=0, ge=0),
        jurisdiction: str = Query(default="NG-Federal", min_length=2, max_length=80),
    ) -> Response:
        try:
            envelope, etag = signed_pack(
                resolved_store._pack,
                layer,
                jurisdiction,
                since,
                app.state.content_signer,
            )
        except ValueError as error:
            raise HTTPException(status_code=404, detail=str(error)) from error
        if request.headers.get("if-none-match") == etag or since >= resolved_store.version:
            return Response(status_code=304, headers={"ETag": etag})
        return JSONResponse(
            envelope,
            headers={
                "ETag": etag,
                "Cache-Control": "public, max-age=300, stale-while-revalidate=86400",
            },
        )

    @app.get("/v1/sync", response_model=UserSyncResponse)
    def pull_user_sync(
        user_id: Annotated[str, Depends(current_user)],
        since: Annotated[datetime | None, Query()] = None,
    ) -> UserSyncResponse:
        return UserSyncResponse(
            items=accounts.user_items(user_id, since),
            server_time=datetime.now(UTC),
        )

    @app.post("/v1/sync", response_model=UserSyncResponse)
    def push_user_sync(
        body: UserSyncRequest,
        user_id: Annotated[str, Depends(current_user)],
    ) -> UserSyncResponse:
        items = [item.model_dump() for item in body.items]
        return UserSyncResponse(
            items=accounts.sync_user_items(user_id, items),
            server_time=datetime.now(UTC),
        )

    if WEB_DIR.exists():

        @app.get("/")
        def index() -> FileResponse:
            return FileResponse(WEB_DIR / "index.html")

        app.mount("/static", StaticFiles(directory=WEB_DIR), name="static")

    return app


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.api:create_app", factory=True, host="127.0.0.1", port=8000, reload=False)
