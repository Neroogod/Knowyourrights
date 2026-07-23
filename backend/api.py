"""KnowYourRights HTTP API (FastAPI).

Serves verified rights content, emergency scenarios, a directory, search, and a
gated, grounded Q&A endpoint. Reference/scenario/directory data is designed to be
cached by the app for offline use; /ask requires connectivity.
"""

import os
from pathlib import Path
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, HTMLResponse, RedirectResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles

from backend.account_schemas import (
    AlertCreate,
    AlertResponse,
    ContactCreate,
    ContactResponse,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    LoginRequest,
    ProfileResponse,
    ProfileUpdate,
    RegisterRequest,
    RegisterResponse,
    ResendVerificationRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyTokenRequest,
)
from backend.accounts import (
    GENERIC_REGISTER_MESSAGE,
    AccountError,
    AccountService,
)
from backend.content_store import ContentStore
from backend.delivery import gateway_from_environment
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
    app = FastAPI(title="KnowYourRights API", version="0.1.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    development_mode = os.getenv("KYR_DEVELOPMENT_MODE") == "1"
    resolved_store = store or ContentStore.from_file()
    accounts = account_service or AccountService(gateway=gateway_from_environment(development_mode))
    bearer = HTTPBearer(auto_error=False)
    app.state.store = resolved_store
    app.state.accounts = accounts

    def current_user(
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    ) -> str:
        if credentials is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="authentication required")
        try:
            return accounts.authenticate(credentials.credentials)
        except AccountError as error:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(error)) from error

    def account_error(error: AccountError) -> HTTPException:
        return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(error))

    @app.get("/v1/health")
    def health() -> dict:
        return {"status": "ok", "content_version": resolved_store.version}

    @app.post("/v1/auth/register", response_model=RegisterResponse)
    def register(request: RegisterRequest) -> RegisterResponse:
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
    def resend_verification(request: ResendVerificationRequest) -> RegisterResponse:
        token = accounts.resend_email_verification(str(request.email))
        return RegisterResponse(
            message=GENERIC_REGISTER_MESSAGE,
            development_verification_token=token if development_mode else None,
            account_exists=accounts.email_exists(str(request.email)),
        )

    @app.post("/v1/auth/login", response_model=TokenResponse)
    def login(request: LoginRequest) -> TokenResponse:
        try:
            token = accounts.login(str(request.email), request.password)
        except AccountError as error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="invalid email or password",
            ) from error
        return TokenResponse(access_token=token)

    @app.post("/v1/auth/forgot-password", response_model=ForgotPasswordResponse)
    def forgot_password(request: ForgotPasswordRequest) -> ForgotPasswordResponse:
        token = accounts.request_password_reset(str(request.email))
        return ForgotPasswordResponse(
            message="If an account exists for this email, a password reset link has been sent.",
            development_reset_token=token if development_mode else None,
        )

    @app.post("/v1/auth/reset-password")
    def reset_password(request: ResetPasswordRequest) -> dict:
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
        contact, token = accounts.create_contact(user_id, request.name, request.phone)
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
        request: AlertCreate,
        user_id: Annotated[str, Depends(current_user)],
    ) -> AlertResponse:
        try:
            alert, duplicate = accounts.create_alert(
                user_id,
                request.contact_id,
                request.idempotency_key,
                request.latitude,
                request.longitude,
                request.accuracy,
            )
        except AccountError as error:
            raise account_error(error) from error
        return AlertResponse(**alert, duplicate=duplicate)

    @app.get("/v1/custody-alerts/{alert_id}", response_model=AlertResponse)
    def get_custody_alert(
        alert_id: str,
        user_id: Annotated[str, Depends(current_user)],
    ) -> AlertResponse:
        try:
            return AlertResponse(**accounts.get_alert(user_id, alert_id))
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
    def ask_company(request: AskRequest) -> AskResponse:
        return resolved_store.ask_company(request.question)

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
    def ask_students(request: AskRequest) -> AskResponse:
        return resolved_store.ask_students(request.question)

    @app.get("/v1/search", response_model=list[Topic])
    def search(q: str = Query(min_length=1)) -> list[Topic]:
        return resolved_store.search_topics(q)

    @app.post("/v1/ask", response_model=AskResponse)
    def ask(request: AskRequest) -> AskResponse:
        return resolved_store.ask(request.question)

    @app.get("/v1/content-pack", response_model=ContentPack)
    def content_pack() -> ContentPack:
        return resolved_store._pack  # full pack for offline caching

    if WEB_DIR.exists():

        @app.get("/")
        def index() -> FileResponse:
            return FileResponse(WEB_DIR / "index.html")

        app.mount("/static", StaticFiles(directory=WEB_DIR), name="static")

    return app


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.api:create_app", factory=True, host="127.0.0.1", port=8000, reload=False)
