"""KnowYourRights HTTP API (FastAPI).

Serves verified rights content, emergency scenarios, a directory, search, and a
gated, grounded Q&A endpoint. Reference/scenario/directory data is designed to be
cached by the app for offline use; /ask requires connectivity.
"""

from pathlib import Path

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from backend.content_store import ContentStore
from backend.schemas import (
    AskRequest,
    AskResponse,
    ContentPack,
    DirectoryEntry,
    Scenario,
    Topic,
)

WEB_DIR = Path(__file__).resolve().parents[1] / "web"


def create_app(store: ContentStore | None = None) -> FastAPI:
    """Application factory so tests can inject a store without touching disk."""
    app = FastAPI(title="KnowYourRights API", version="0.1.0")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    resolved_store = store or ContentStore.from_file()
    app.state.store = resolved_store

    @app.get("/v1/health")
    def health() -> dict:
        return {"status": "ok", "content_version": resolved_store.version}

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
