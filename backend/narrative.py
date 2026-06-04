"""Task 5 — Claude API 기반 어트랙션 서사 생성.

attractions/{id}/history_text 를 Firestore 에서 읽어 컨텍스트 프롬프트에 주입한다.

디스크 캐시: 같은 attraction × locale × season × companion_type 조합은 변동 없는
서사 — 한 번 생성되면 ./cache/narratives/{key}.json 으로 보관해 재호출 시 즉시 반환.
v2 백엔드 story.py 의 캐시 패턴을 가져옴. ANTHROPIC_API_KEY 미설정 (fallback)
케이스는 캐시하지 않음 (룰 기반은 즉시 생성).
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
from dataclasses import dataclass
from pathlib import Path

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


_CACHE_DIR = Path(os.environ.get("NARRATIVE_CACHE_DIR", "./cache/narratives"))


def _cache_key(attraction_id: str, locale: str, season: str, companion_type: str) -> str:
    raw = f"{attraction_id}|{locale}|{season}|{companion_type}"
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:16]


def _cache_get(key: str) -> dict | None:
    path = _CACHE_DIR / f"{key}.json"
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text("utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _cache_put(key: str, data: dict) -> None:
    try:
        _CACHE_DIR.mkdir(parents=True, exist_ok=True)
        (_CACHE_DIR / f"{key}.json").write_text(
            json.dumps(data, ensure_ascii=False, indent=2), "utf-8"
        )
    except OSError as e:
        logger.warning("narrative — cache write failed: %s", e)


def _get_client() -> Anthropic:
    global _client
    if _client is None:
        api_key = os.getenv("ANTHROPIC_API_KEY")
        if not api_key:
            raise RuntimeError("ANTHROPIC_API_KEY env var is not set")
        _client = Anthropic(api_key=api_key)
    return _client


def _fallback_narrative(
    attraction_name: str, companion_type: str, season: str, locale: str = "ko"
) -> str:
    """API key 없거나 Anthropic 호출 실패 시 로컬 룰 기반 fallback.

    locale='en' 이면 영어 버전. 그 외엔 한국어.
    """
    if locale == "en":
        season_phrase = {
            "spring": "a cherry-blossom day",
            "summer": "a sun-drenched summer",
            "autumn": "an autumn at the peak of color",
            "winter": "a quiet, snow-falling winter",
        }.get(season, "a memorable day")
        companion_phrase = {
            "혼자": "a solo footprint",
            "연인": "two together's footsteps",
            "친구": "friends' footsteps",
            "가족": "a family's footsteps",
        }.get(companion_type, "your footsteps")
        return (
            f"{attraction_name}. On {season_phrase}, {companion_phrase} made a page here. "
            f"Since opening in 1988, countless memories have piled up at this very spot — "
            f"and today, your visit adds a new chapter 🌙"
        )

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
    locale: str = "ko",
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

    # 디스크 캐시 hit — Claude 호출 없이 즉시 반환.
    cache_key = _cache_key(attraction_id, locale, season, companion_type)
    cached = _cache_get(cache_key)
    if cached:
        logger.info("narrative — cache hit %s", cache_key)
        return NarrativeOutput(
            attraction_id=attraction_id,
            attraction_name=cached.get("attraction_name") or name,
            narrative=cached["narrative"],
        )

    # Anthropic API 미설정 시 룰 기반 fallback (서비스 안 끊기게). 캐시 안 함.
    if not os.getenv("ANTHROPIC_API_KEY"):
        logger.info("narrative — ANTHROPIC_API_KEY missing, using fallback")
        return NarrativeOutput(
            attraction_id=attraction_id,
            attraction_name=name,
            narrative=_fallback_narrative(name, companion_type, season, locale),
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
            text = _fallback_narrative(name, companion_type, season, locale)
            cached_ok = False
        else:
            cached_ok = True
    except Exception as e:
        logger.warning("narrative — Anthropic call failed (%s), using fallback", e)
        text = _fallback_narrative(name, companion_type, season, locale)
        cached_ok = False

    # Claude 성공 응답만 캐시 — 룰 기반 fallback 은 매번 생성 가능하므로 캐시 의미 없음.
    if cached_ok:
        _cache_put(cache_key, {
            "attraction_id": attraction_id,
            "attraction_name": name,
            "narrative": text,
            "model": model,
            "locale": locale,
            "season": season,
            "companion_type": companion_type,
        })

    return NarrativeOutput(attraction_id=attraction_id, attraction_name=name, narrative=text)
