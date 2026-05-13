import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")


# ── 기상청 API ────────────────────────────────────────────────
# data.go.kr 에서 발급받은 일반 인증키 (decoded)
KMA_SERVICE_KEY = os.getenv("KMA_SERVICE_KEY", "")
KMA_VILAGE_FCST_URL = (
    "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst"
)

# 서울랜드(경기 과천) 기상청 격자 좌표
SEOULLAND_NX = int(os.getenv("SEOULLAND_NX", 60))
SEOULLAND_NY = int(os.getenv("SEOULLAND_NY", 120))


# ── XGBoost 모델 ─────────────────────────────────────────────
# 학습된 회귀 모델 (joblib.dump 형식). 일일 입장객 수를 예측.
MODEL_PATH = BASE_DIR / os.getenv("MODEL_PATH", "artifacts/crowd_model.pkl")

# 입력 피처 순서 (학습 시 컬럼 순서와 반드시 일치)
FEATURE_ORDER = [
    "hour",
    "weekday",
    "is_holiday",
    "temp",
    "rain_prob",
    "is_event",
    "pre_sales",
]

# 회귀 예측값 → 혼잡도 등급 변환 임계치 (일일 입장객 수 기준)
# 보고서 §2.2: 비수기 평일 1,355명/일, 주말·성수기 ~10,000명 이상
CROWD_THRESHOLDS = {
    "low_max": float(os.getenv("CROWD_LOW_MAX", 2500)),
    "mid_max": float(os.getenv("CROWD_MID_MAX", 5500)),
}


# ── Firebase / FCM ───────────────────────────────────────────
FIREBASE_CREDENTIALS_PATH = BASE_DIR / os.getenv(
    "FIREBASE_CREDENTIALS_PATH", "secrets/firebase-admin.json"
)
FCM_TOPIC = os.getenv("FCM_TOPIC", "all_users")


# ── Scheduler ────────────────────────────────────────────────
SCHEDULER_TIMEZONE = os.getenv("SCHEDULER_TIMEZONE", "Asia/Seoul")
SCHEDULER_ENABLED = os.getenv("SCHEDULER_ENABLED", "1") == "1"
