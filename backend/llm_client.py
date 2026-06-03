"""Anthropic Claude API 래퍼.

ANTHROPIC_API_KEY 환경변수가 없으면 자동으로 스텁(고정 문구) 반환 — 키 없이도 엔드포인트 동작.
키를 나중에 환경변수에 추가하면 코드 수정 없이 즉시 실제 호출로 전환.
"""
import logging
import os
from typing import Optional

log = logging.getLogger(__name__)

_client = None  # 지연 초기화 (키 없을 때 import 단계 실패 방지)

# 다국어 — 서사 / 푸시 양쪽 공통
_LANG_NAMES = {
    "ko": "한국어",
    "en": "English",
    "ja": "日本語",
    "zh": "中文",
}

_STORY_TITLE_LABELS = {
    "ko": "제목",
    "en": "Title",
    "ja": "タイトル",
    "zh": "标题",
}
_STORY_BODY_LABELS = {
    "ko": "본문",
    "en": "Body",
    "ja": "本文",
    "zh": "正文",
}


def _has_key() -> bool:
    return bool(os.environ.get("ANTHROPIC_API_KEY"))


def _model_id() -> str:
    """LLM_MODEL env 우선, 미설정 시 Sonnet 4 기본 (명세 6.2 항목)."""
    return os.environ.get("LLM_MODEL", "claude-sonnet-4-6")


def _get_client():
    global _client
    if _client is None:
        from anthropic import Anthropic
        _client = Anthropic()
    return _client


def _parse_response(text: str, fallback_title: str, language: str = "ko") -> tuple[str, str]:
    """'<제목 라벨>: ...\n<본문 라벨>: ...' 포맷 → (title, body)."""
    title_lbl = _STORY_TITLE_LABELS.get(language, "Title") + ":"
    body_lbl = _STORY_BODY_LABELS.get(language, "Body") + ":"
    title = fallback_title
    body = text.strip()
    for line in text.strip().splitlines():
        if line.startswith(title_lbl):
            title = line[len(title_lbl):].strip()
        elif line.startswith(body_lbl):
            body = line[len(body_lbl):].strip()
    return title, body


def generate_route_narrative(
    steps: list[dict], members: list[dict], available_minutes: int
) -> Optional[str]:
    """동선 안내문 생성. 키 없으면 None 반환 (호출부에서 fallback)."""
    if not _has_key():
        return None

    member_lines = ", ".join(
        f"{m['age']}세(스릴 {m['thrill_pref']}/5{', 어린이 동반' if m.get('has_kids_role') else ''})"
        for m in members
    )
    step_lines = "\n".join(
        f"{s['order']}. {s['name']} (시작 후 {s['arrival_minute_from_start']}분, "
        f"이동 {s['travel_minutes']}분/대기 {s['wait_minutes']}분/체류 {s['stay_minutes']}분)"
        for s in steps
    )

    prompt = (
        f"당신은 서울랜드 방문 가이드입니다. 다음 동선을 따라가는 방문객에게 "
        f"친근한 한국어 안내문을 작성하세요. **150자 이내**, 핵심 포인트와 흐름만 짧게.\n\n"
        f"구성원: {member_lines}\n"
        f"총 가용 시간: {available_minutes}분\n"
        f"동선:\n{step_lines}\n\n"
        f"안내문(150자 이내):"
    )
    try:
        client = _get_client()
        msg = client.messages.create(
            model=_model_id(),
            max_tokens=400,
            messages=[{"role": "user", "content": prompt}],
        )
        return msg.content[0].text.strip()
    except Exception as e:
        log.warning("동선 안내문 생성 실패 — fallback 으로 None 반환: %s", e)
        return None


def generate_story(attraction: dict, language: str = "ko") -> dict:
    """어트랙션 정보 기반 짧은 서사 생성. 다국어 지원.

    language: 'ko' | 'en' | 'ja' | 'zh'. 기본 한국어.
    반환: { title, body, model, version, language }
    """
    lang_name = _LANG_NAMES.get(language, "한국어")
    if not _has_key():
        log.info("ANTHROPIC_API_KEY 없음 — 스텁 응답 반환 (attraction=%s lang=%s)", attraction["id"], language)
        stub_body = {
            "ko": f"{attraction['name']}는 서울랜드의 인기 어트랙션입니다.",
            "en": f"{attraction['name']} is a popular attraction at Seoul Land.",
            "ja": f"{attraction['name']}はソウルランドの人気アトラクションです。",
            "zh": f"{attraction['name']}是首尔乐园的人气游乐设施。",
        }.get(language, attraction["name"])
        return {
            "title": f"{attraction['name']}",
            "body": stub_body + " (ANTHROPIC_API_KEY 미설정 — 스텁 응답)",
            "model": "stub",
            "version": "stub-v2",
            "language": language,
        }

    client = _get_client()
    title_lbl = _STORY_TITLE_LABELS.get(language, "Title")
    body_lbl = _STORY_BODY_LABELS.get(language, "Body")
    prompt = (
        f"You are a storyteller for the Seoul Land attraction "
        f"'{attraction['name']}' (type: {attraction['type']}). "
        f"Write a short, engaging backstory in **{lang_name}** (within 200 characters) "
        f"that helps visitors enjoy the ride more. "
        f"Respond strictly in this format:\n\n"
        f"{title_lbl}: <one-line title>\n{body_lbl}: <body within 200 chars>"
    )
    msg = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=500,
        messages=[{"role": "user", "content": prompt}],
    )
    text = msg.content[0].text
    title, body = _parse_response(text, attraction["name"], language)
    return {
        "title": title,
        "body": body,
        "model": _model_id(),
        "version": "v2",
        "language": language,
    }


# ──────────────── 재방문 푸시 ────────────────

_PUSH_STUB = {
    "incomplete_chapter_30d": {
        "title": "아직 완성하지 못한 챕터가 기다리고 있어요",
        "body": "잠시 들러 빠진 책을 모아 챕터를 완성해 보세요.",
    },
    "elapsed_14d": {
        "title": "서울랜드, 다시 만날 시간!",
        "body": "2주 만에 방문해 새로운 어트랙션 추천을 받아보세요.",
    },
    "season_refresh": {
        "title": "새 계절 챕터가 열렸어요",
        "body": "이번 시즌 한정 책을 모아 연대기를 완성해 보세요.",
    },
}


def generate_push_message(trigger: str) -> dict:
    """재방문 트리거별 푸시 메시지 LLM 생성. 키 없으면 고정 스텁.

    trigger: 'incomplete_chapter_30d' | 'elapsed_14d' | 'season_refresh'
    반환: { title, body }
    """
    if not _has_key():
        return _PUSH_STUB.get(trigger, _PUSH_STUB["elapsed_14d"])

    context_lines = {
        "incomplete_chapter_30d": (
            "사용자는 30일 넘게 방문하지 않았고, 완성하지 못한 연대기 챕터가 있습니다. "
            "잠깐 들러서 빠진 책(이스터에그)을 마저 모으도록 따뜻하게 권유하세요."
        ),
        "elapsed_14d": (
            "사용자는 2주 전 마지막 방문 후 방문 기록이 없습니다. "
            "그동안 새로 추천할 수 있는 어트랙션이 있다고 가볍게 호기심을 자극하세요."
        ),
        "season_refresh": (
            "오늘부터 새 계절 챕터가 열렸습니다. 시즌 한정 책을 모아 "
            "연대기를 완성하는 재미를 강조해 방문을 권유하세요."
        ),
    }
    context = context_lines.get(trigger, context_lines["elapsed_14d"])

    prompt = (
        f"당신은 서울랜드 앱의 푸시 알림 작성자입니다. 한국어로 다음 형식의 짧고 매력적인 "
        f"푸시 메시지를 작성하세요.\n\n"
        f"맥락: {context}\n\n"
        f"형식 (제목 25자 이내, 본문 60자 이내):\n"
        f"제목: <제목>\n본문: <본문>"
    )
    try:
        client = _get_client()
        msg = client.messages.create(
            model=_model_id(),
            max_tokens=300,
            messages=[{"role": "user", "content": prompt}],
        )
        title, body = _parse_response(msg.content[0].text, _PUSH_STUB[trigger]["title"], "ko")
        return {"title": title, "body": body}
    except Exception as e:
        log.warning("푸시 메시지 LLM 생성 실패 — 스텁 반환: %s", e)
        return _PUSH_STUB.get(trigger, _PUSH_STUB["elapsed_14d"])
