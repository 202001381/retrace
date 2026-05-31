"""기상청 단기예보 API 호출 + XGBoost 입력 피처 정규화."""
from datetime import datetime, timedelta
from typing import Dict, Tuple

import pytz
import requests

from config import Config

_KST = pytz.timezone("Asia/Seoul")

# 기상청 단기예보 발표 시각 (KST)
_BASE_TIMES = ["0200", "0500", "0800", "1100", "1400", "1700", "2000", "2300"]


def _latest_base_datetime(now: datetime) -> Tuple[str, str]:
    """가장 가까운 과거 발표 시각 (base_date, base_time) 반환.

    발표 후 데이터 반영까지 약 10분 지연이 있어 안전 마진을 둔다.
    """
    now_kst = now.astimezone(_KST) - timedelta(minutes=10)
    today = now_kst.strftime("%Y%m%d")
    current_hm = now_kst.strftime("%H%M")
    for base_time in reversed(_BASE_TIMES):
        if current_hm >= base_time:
            return today, base_time
    yesterday = (now_kst - timedelta(days=1)).strftime("%Y%m%d")
    return yesterday, "2300"


def _parse_precip(raw: str) -> float:
    """기상청 PCP/RN1 문자열을 mm float로 변환.

    예: '강수없음', '1mm 미만', '1.0mm', '30.0~50.0mm'
    """
    if not raw or raw in ("강수없음", "-"):
        return 0.0
    raw = raw.replace("mm", "").strip()
    if "미만" in raw:
        return 0.5
    if "~" in raw:
        try:
            lo, hi = raw.split("~")
            return (float(lo) + float(hi)) / 2.0
        except ValueError:
            return 0.0
    try:
        return float(raw)
    except ValueError:
        return 0.0


def fetch_features(config: Config, target_hour: int | None = None) -> Dict[str, float]:
    """기상청 단기예보 호출 → XGBoost 입력 dict 생성.

    target_hour: 예측 대상 시각(0-23, KST). None이면 호출 시각의 다음 정시.
    """
    now = datetime.now(_KST)
    base_date, base_time = _latest_base_datetime(now)

    if target_hour is None:
        target_hour = (now.hour + 1) % 24
    target_fcst_time = f"{target_hour:02d}00"

    params = {
        "serviceKey": config.kma_api_key,
        "pageNo": "1",
        "numOfRows": "1000",
        "dataType": "JSON",
        "base_date": base_date,
        "base_time": base_time,
        "nx": str(config.kma_nx),
        "ny": str(config.kma_ny),
    }
    resp = requests.get(config.kma_base_url, params=params, timeout=10)
    resp.raise_for_status()
    payload = resp.json()
    items = (
        payload.get("response", {})
        .get("body", {})
        .get("items", {})
        .get("item", [])
    )

    categories: Dict[str, str] = {}
    for item in items:
        if item.get("fcstTime") == target_fcst_time:
            categories[item["category"]] = item["fcstValue"]

    return {
        "temp_c": float(categories.get("TMP", 15.0)),
        "humidity": float(categories.get("REH", 60.0)),
        "precip_mm": _parse_precip(categories.get("PCP", "강수없음")),
        "wind_ms": float(categories.get("WSD", 1.0)),
        "sky": float(categories.get("SKY", 1)),
        "pty": float(categories.get("PTY", 0)),
        "hour": float(target_hour),
        "day_of_week": float(now.weekday()),
        "month": float(now.month),
        "is_weekend": 1.0 if now.weekday() >= 5 else 0.0,
    }
