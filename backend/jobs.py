"""스케줄러 작업 정의.

- refresh_weather_score: 기상청 → XGBoost → Firestore (07:00 KST)
- send_revisit_pushes: 사용자 순회 → 재방문 트리거 → FCM (22:00 KST)

가정 — users/{uid} 문서 스키마:
    fcmToken: str
    lastVisitAt: Timestamp (KST 또는 UTC, tz-aware)
    hasIncompleteChapter: bool
"""
import logging
from datetime import datetime, timedelta
from typing import Dict, List

import pytz
from firebase_admin import firestore as fs

from config import Config
from fcm_sender import send_to_tokens
from llm_client import generate_push_message
from weather_client import fetch_features
from xgboost_model import VisitValueModel

log = logging.getLogger(__name__)
_KST = pytz.timezone("Asia/Seoul")

# 계절 챕터 갱신일 = 매 분기 시작 (KST 기준)
_SEASON_START_DATES = {(3, 1), (6, 1), (9, 1), (12, 1)}


def refresh_weather_score(config: Config, model: VisitValueModel, db) -> Dict:
    """기상청 단기예보 → XGBoost 예측 → valueScoreSnapshot/current 갱신."""
    features = fetch_features(config)
    score = model.predict(features)

    db.collection("valueScoreSnapshot").document("current").set(
        {
            "score": score,
            "features": features,
            "computedAt": fs.SERVER_TIMESTAMP,
        }
    )
    log.info("valueScoreSnapshot 갱신: score=%.1f", score)
    return {"score": score, "features": features}


def send_revisit_pushes(config: Config, db) -> Dict[str, Dict[str, int]]:
    """세 가지 재방문 트리거를 평가해 FCM 발송.

    트리거 우선순위 (상호 배타):
    1. 30일 경과 + 미완성 챕터  → '미완성 챕터' 메시지
    2. 14일 경과 (30일 미만)     → '재방문' 메시지
    3. 오늘이 계절 챕터 갱신일   → 1·2에 해당하지 않는 활성 사용자에게 시즌 메시지
    """
    now = datetime.now(_KST)
    today = now.date()
    threshold_14 = now - timedelta(days=14)
    threshold_30 = now - timedelta(days=30)
    is_season_refresh_day = (today.month, today.day) in _SEASON_START_DATES

    tokens_30d_incomplete: List[str] = []
    tokens_14d: List[str] = []
    tokens_season: List[str] = []

    # 사용자 수가 늘면 pagination + Cloud Tasks fan-out 으로 분산 필요
    for user_doc in db.collection("users").stream():
        user = user_doc.to_dict() or {}
        token = user.get("fcmToken")
        if not token:
            continue

        last_visit = user.get("lastVisitAt")
        if hasattr(last_visit, "to_pydatetime"):
            last_visit = last_visit.to_pydatetime()
        if last_visit is not None and last_visit.tzinfo is None:
            last_visit = _KST.localize(last_visit)

        matched = False
        if last_visit and last_visit <= threshold_30 and user.get("hasIncompleteChapter"):
            tokens_30d_incomplete.append(token)
            matched = True
        elif last_visit and threshold_30 < last_visit <= threshold_14:
            tokens_14d.append(token)
            matched = True

        if is_season_refresh_day and not matched:
            tokens_season.append(token)

    summary: Dict[str, Dict[str, int]] = {}
    # 트리거별로 LLM 메시지 1회씩 생성 (해당 트리거의 모든 사용자에게 동일 메시지 전송)
    # — Claude 호출 3회/일 한도. 비용 미미.
    if tokens_30d_incomplete:
        m = generate_push_message("incomplete_chapter_30d")
        summary["incomplete_30d"] = send_to_tokens(
            tokens_30d_incomplete,
            title=m["title"], body=m["body"],
            data={"trigger": "incomplete_chapter_30d"},
            dry_run=config.fcm_dry_run,
        )
    if tokens_14d:
        m = generate_push_message("elapsed_14d")
        summary["elapsed_14d"] = send_to_tokens(
            tokens_14d,
            title=m["title"], body=m["body"],
            data={"trigger": "elapsed_14d"},
            dry_run=config.fcm_dry_run,
        )
    if tokens_season:
        m = generate_push_message("season_refresh")
        summary["season_refresh"] = send_to_tokens(
            tokens_season,
            title=m["title"], body=m["body"],
            data={"trigger": "season_refresh"},
            dry_run=config.fcm_dry_run,
        )
    log.info("재방문 푸시 발송 요약: %s", summary)
    return summary
