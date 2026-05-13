"""Task 5 — Claude API 기반 어트랙션 서사 생성.

attractions/{id}/history_text 를 Firestore 에서 읽어 컨텍스트 프롬프트에 주입한다.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass

from anthropic import Anthropic

from . import firestore_client

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = (
    "당신은 서울랜드의 38년 역사를 개인화된 이야기로 전달하는 스토리텔러입니다. "
    "방문객의 상황(동행자, 날씨, 계절, 방문 이력)을 반영하여 "
    "해당 어트랙션의 역사와 방문객의 현재 순간을 연결하는 짧은 서사(100자 내외)를 생성하세요. "
    "말투는 따뜻하고 감성적으로, 과거와 현재를 자연스럽게 연결해주세요."
)

_USER_TEMPLATE = (
    "어트랙션: {attraction_name}\n"
    "역사 정보: {attraction_history_text}\n"
    "방문객 상황: {companion_type}, {season}, {weather}, "
    "오늘 방문한 어트랙션 수: {visit_count}번째\n"
    "위 정보를 바탕으로 이 순간의 서사를 생성해주세요."
)


@dataclass
class NarrativeOutput:
    attraction_id: str
    attraction_name: str
    narrative: str


_client: Anthropic | None = None


def _get_client() -> Anthropic:
    global _client
    if _client is None:
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY env var is not set")
        _client = Anthropic(api_key=api_key)
    return _client


def generate_narrative(
    *,
    attraction_id: str,
    companion_type: str,
    season: str,
    weather: str,
    visit_count: int,
    model: str = "claude-sonnet-4-6",
) -> NarrativeOutput:
    attraction = firestore_client.get_attraction(attraction_id)
    if not attraction:
        raise LookupError(f"attraction not found: {attraction_id}")

    name = attraction.get("name") or attraction_id
    history = attraction.get("history_text") or ""

    user_prompt = _USER_TEMPLATE.format(
        attraction_name=name,
        attraction_history_text=history,
        companion_type=companion_type,
        season=season,
        weather=weather,
        visit_count=visit_count,
    )

    client = _get_client()
    resp = client.messages.create(
        model=model,
        max_tokens=400,
        system=_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_prompt}],
    )

    text = "".join(block.text for block in resp.content if hasattr(block, "text")).strip()
    return NarrativeOutput(attraction_id=attraction_id, attraction_name=name, narrative=text)
