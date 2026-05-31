"""Anthropic Claude API 래퍼.

ANTHROPIC_API_KEY 환경변수가 없으면 자동으로 스텁(고정 문구) 반환 — 키 없이도 엔드포인트 동작.
키를 나중에 환경변수에 추가하면 코드 수정 없이 즉시 실제 호출로 전환.
"""
import logging
import os

log = logging.getLogger(__name__)

_client = None  # 지연 초기화 (키 없을 때 import 단계 실패 방지)


def _has_key() -> bool:
    return bool(os.environ.get("ANTHROPIC_API_KEY"))


def _get_client():
    global _client
    if _client is None:
        from anthropic import Anthropic  # 지연 import — 키 없을 때 dep 미설치여도 OK
        _client = Anthropic()  # ANTHROPIC_API_KEY 자동 사용
    return _client


def _parse_response(text: str, fallback_title: str) -> tuple[str, str]:
    """'제목: ...\n본문: ...' 포맷을 (title, body)로 분리. 실패 시 전체를 body로."""
    title = fallback_title
    body = text.strip()
    for line in text.strip().splitlines():
        if line.startswith("제목:"):
            title = line[len("제목:"):].strip()
        elif line.startswith("본문:"):
            body = line[len("본문:"):].strip()
    return title, body


def generate_route_narrative(steps: list[dict], members: list[dict], available_minutes: int) -> str | None:
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
            model="claude-haiku-4-5",
            max_tokens=400,
            messages=[{"role": "user", "content": prompt}],
        )
        return msg.content[0].text.strip()
    except Exception as e:
        log.warning("동선 안내문 생성 실패 — fallback 으로 None 반환: %s", e)
        return None


def generate_story(attraction: dict) -> dict:
    """어트랙션 정보 기반 짧은 서사 생성.

    반환: { title, body, model, version }
    """
    if not _has_key():
        log.info("ANTHROPIC_API_KEY 없음 — 스텁 응답 반환 (attraction=%s)", attraction["id"])
        return {
            "title": f"{attraction['name']} 이야기",
            "body": (
                f"{attraction['name']}는 서울랜드의 인기 어트랙션입니다. "
                f"(현재 ANTHROPIC_API_KEY가 설정되지 않아 임시 문구를 반환합니다. "
                f"키를 환경변수에 추가하시면 Claude AI가 생성한 서사로 자동 전환됩니다.)"
            ),
            "model": "stub",
            "version": "stub-v1",
        }

    client = _get_client()
    prompt = (
        f"당신은 서울랜드 어트랙션 '{attraction['name']}' (종류: {attraction['type']})의 "
        f"스토리텔러입니다. 방문객이 어트랙션을 더 즐길 수 있도록 200자 이내의 짧고 "
        f"흥미로운 배경 서사를 한국어로 작성하세요. 다음 형식으로만 답하세요.\n\n"
        f"제목: <한 줄 제목>\n본문: <200자 이내 본문>"
    )
    msg = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=500,
        messages=[{"role": "user", "content": prompt}],
    )
    text = msg.content[0].text
    title, body = _parse_response(text, attraction["name"])
    return {
        "title": title,
        "body": body,
        "model": "claude-haiku-4-5",
        "version": "v1",
    }
