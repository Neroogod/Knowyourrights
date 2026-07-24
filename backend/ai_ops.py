"""Production controls around grounded legal AI requests."""

from __future__ import annotations

import hashlib
import hmac
import os
import re
import time
from collections.abc import Callable
from dataclasses import dataclass

from backend.accounts import AccountService
from backend.schemas import AskResponse

_SPACE = re.compile(r"\s+")


@dataclass(frozen=True)
class AIRequestContext:
    corpus: str
    jurisdiction: str
    privacy_id: str
    user_id: str | None


class AIProductionGate:
    """Cache, quota, privacy, sampling, latency, and cost boundary for RAG."""

    def __init__(
        self,
        accounts: AccountService,
        content_version: int,
        *,
        model_key: str | None = None,
    ) -> None:
        self.accounts = accounts
        self.content_version = content_version
        self.model_key = model_key or os.getenv("KYR_OPENAI_MODEL", "extractive-or-configured-generator")
        self.daily_quota = int(os.getenv("KYR_AI_DAILY_QUOTA", "50"))
        self.cache_ttl = int(os.getenv("KYR_AI_CACHE_TTL_SECONDS", "21600"))
        self.sample_rate = float(os.getenv("KYR_AI_REVIEW_SAMPLE_RATE", "0.02"))
        self.input_cost_per_million = float(os.getenv("KYR_AI_INPUT_COST_PER_MILLION", "0"))
        self.output_cost_per_million = float(os.getenv("KYR_AI_OUTPUT_COST_PER_MILLION", "0"))

    def privacy_id(self, raw_identifier: str) -> str:
        """Daily rotating HMAC; neither an IP, device ID, nor email is stored."""
        day = time.strftime("%Y-%m-%d", time.gmtime())
        key = hmac.new(
            self.accounts.secret.encode(),
            f"ai-safety:{day}".encode(),
            hashlib.sha256,
        ).digest()
        return hmac.new(key, raw_identifier.encode(), hashlib.sha256).hexdigest()

    def answer(
        self,
        question: str,
        context: AIRequestContext,
        answerer: Callable[[str], AskResponse],
        *,
        incognito: bool = False,
    ) -> tuple[AskResponse, bool, str]:
        # An incognito session neither reads nor writes the answer cache and
        # records no telemetry, so a sensitive question ("can they detain me
        # for X?") leaves no trace. The hourly rate limit still applies.
        if incognito:
            if self.accounts.ai_daily_usage(context.privacy_id) >= self.daily_quota:
                raise PermissionError("Daily AI question limit reached. Try again tomorrow.")
            return answerer(question), False, "incognito"
        normalized = _SPACE.sub(" ", question.strip().lower())
        cache_key = hashlib.sha256(
            (
                f"{self.content_version}|{self.model_key}|{context.corpus}|"
                f"{context.jurisdiction}|{normalized}"
            ).encode()
        ).hexdigest()
        started = time.perf_counter()
        cached = self.accounts.ai_cache_get(cache_key)
        if cached is not None:
            response = AskResponse.model_validate(cached)
            event_id = self._record(
                question,
                response,
                context,
                started,
                cache_hit=True,
            )
            return response, True, event_id

        if self.accounts.ai_daily_usage(context.privacy_id) >= self.daily_quota:
            raise PermissionError("Daily AI question limit reached. Try again tomorrow.")

        response = answerer(question)
        payload = response.model_dump(mode="json")
        self.accounts.ai_cache_put(
            cache_key,
            payload,
            content_version=self.content_version,
            model_key=self.model_key,
            ttl_seconds=self.cache_ttl,
        )
        event_id = self._record(
            question,
            response,
            context,
            started,
            cache_hit=False,
        )
        return response, False, event_id

    def _record(
        self,
        question: str,
        response: AskResponse,
        context: AIRequestContext,
        started: float,
        *,
        cache_hit: bool,
    ) -> str:
        # Token counts are deliberately provider-neutral estimates when the model
        # does not expose usage. They keep dashboards useful without retaining prompts.
        input_tokens = max(1, len(question) // 4)
        output_tokens = max(1, len(response.answer) // 4)
        estimated_cost = (
            input_tokens * self.input_cost_per_million + output_tokens * self.output_cost_per_million
        ) / 1_000_000
        return self.accounts.record_ai_usage(
            privacy_id=context.privacy_id,
            user_id=context.user_id,
            corpus=context.corpus,
            jurisdiction=context.jurisdiction,
            model_key=self.model_key,
            latency_ms=max(0, int((time.perf_counter() - started) * 1000)),
            input_tokens=input_tokens,
            output_tokens=output_tokens,
            estimated_cost_usd=estimated_cost,
            cache_hit=cache_hit,
            refused=response.refused,
            response=response.model_dump(mode="json"),
            sample_rate=self.sample_rate,
        )
