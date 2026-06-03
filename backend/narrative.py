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


def _fallback_narrative(attraction_name: str, companion_type: str, season: str) -> str:
    """API key 없거나 Anthropic 호출 실패 시 로컬 룰 기반 fallback.

    시연·테스트 환경에서도 화면이 끊기지 않도록. season + companion 조합으로
    8가지 톤 변화.
    """
    season_phrase = {
        "spring": "벚꽃이 흩날리던",
        "summer": "햇볕이 짙던 여름",
        "autumn": "단풍이 절정이던 가을",
        "winter": "눈이 내리던 겨울",
    }.get(season, "기억에 남는")
    companion_phrase = {
        "혼자": "혼자만의 발걸음",
        "연인": "둘만의 발걸음",
        "친구": "친구들과 함께한 발걸음",
        "가족": "가족과 함께한 발걸음",
    }.get(companion_type, "당신의 발걸음")
    return (
        f"{attraction_name}. {season_phrase} 날, {companion_phrase}이 만든 한 페이지입니다. "
        f"1988년 개장 이래 셀 수 없이 많은 사람들의 기억이 이 자리에 쌓였고, "
        f"오늘 당신의 방문이 새로운 챕터를 더합니다 🌙"
    )


def generate_narrative(
    *,
    attraction_id: str,
    companion_type: str,
    season: str,
    weather: str,
    visit_count: int,
    model: str = "claude-sonnet-4-6",
) -> NarrativeOutput:
    # Firestore 미가용 (credentials 없음·offline 등) 시 attractions.json 으로
    # 조용히 fallback. 베타 환경에서 admin SDK 안 깔려도 narrative 동작 보장.
    attraction = None
    try:
        attraction = firestore_client.get_attraction(attraction_id)
    except Exception as e:
        logger.info("narrative — firestore unavailable (%s), using json fallback", e)
    if not attraction:
        try:
            import json
            from pathlib import Path
            data = json.loads(
                Path(__file__).parent.joinpath("attractions.json").read_text("utf-8")
            )
            attraction = next((a for a in data if a["id"] == attraction_id), None)
        except Exception as e:
            logger.warning("narrative — attractions.json read failed: %s", e)
    if not attraction:
        raise LookupError(f"attraction not found: {attraction_id}")

    name = attraction.get("name") or attraction_id
    history = attraction.get("history_text") or attraction.get("description") or ""

    # Anthropic API 미설정 시 룰 기반 fallback (서비스 안 끊기게).
    if not os.getenv("ANTHROPIC_API_KEY"):
        logger.info("narrative — ANTHROPIC_API_KEY missing, using fallback")
        return NarrativeOutput(
            attraction_id=attraction_id,
            attraction_name=name,
            narrative=_fallback_narrative(name, companion_type, season),
        )

    user_prompt = _USER_TEMPLATE.format(
        attraction_name=name,
        attraction_history_text=history,
        companion_type=companion_type,
        season=season,
        weather=weather,
        visit_count=visit_count,
    )

    try:
        client = _get_client()
        resp = client.messages.create(
            model=model,
            max_tokens=400,
            system=_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_prompt}],
        )
        text = "".join(block.text for block in resp.content if hasattr(block, "text")).strip()
        if not text:
            text = _fallback_narrative(name, companion_type, season)
    except Exception as e:
        logger.warning("narrative — Anthropic call failed (%s), using fallback", e)
        text = _fallback_narrative(name, companion_type, season)

    return NarrativeOutput(attraction_id=attraction_id, attraction_name=name, narrative=text)
