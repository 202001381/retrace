"""Stub 모델 학습 — 실 서울랜드 방문객 데이터 없는 상황에서 파이프라인이
'동작은' 하도록 만드는 합성 데이터 학습 스크립트.

⚠️ 이건 데모용. 실 운영 데이터 확보 후 swap 필수.

합성 데이터 생성 룰 (서울랜드 보고서 §2.2 평일 1,355명·주말~10k 명 베이스):
  base       = 평일 1500, 주말 7000
  hour curve = 14~16시 ×1.5 / 10시·18시 ×0.5
  공휴일     = +3000
  기온       = 22°C 이상적, 멀어지면 선형 감소; <10°C 또는 >30°C 추가 -30%
  강수확률   = 50%+ 시 -40%, 70%+ 시 -60%
  이벤트     = +1500
  pre_sales  = +sales × 0.7 (포화)
  + Gaussian noise σ=10%

학습 후 joblib.dump 로 config.MODEL_PATH 에 저장.

실행:
    cd backend && python train_stub.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split
from xgboost import XGBRegressor

# `python backend/train_stub.py` (모듈 경로 외부 실행) 호환을 위해 sys.path 보정.
if __package__ is None or __package__ == "":
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from backend import config  # noqa: E402  (sys.path 조정 후 import)


N_SAMPLES = 5000
SEED = 42
NOISE_PCT = 0.10


def _hour_factor(hour: int) -> float:
    """시간대별 방문 강도. 14~16시 피크, 10시·18시 저점."""
    # bell curve 근사: 14시 정점.
    peak = 14
    spread = 4.0
    base = np.exp(-((hour - peak) ** 2) / (2 * spread ** 2))
    return 0.35 + 1.3 * base  # min ~0.35, max ~1.65


def _generate(n: int, rng: np.random.Generator) -> pd.DataFrame:
    """합성 입력 + 'true' visitor_count 생성."""
    hours = rng.integers(10, 19, size=n)          # 10~18시 운영시간
    weekdays = rng.integers(0, 7, size=n)         # 0=월 ~ 6=일
    is_holiday = rng.random(n) < 0.10             # 10% 공휴일
    temps = rng.normal(20, 8, size=n).clip(-5, 38)
    rain_prob = rng.integers(0, 101, size=n)
    is_event = rng.random(n) < 0.15               # 15% 이벤트
    pre_sales = rng.integers(0, 4001, size=n)     # 0~4000장

    # visitor count 합성
    is_weekend = (weekdays >= 5) | is_holiday
    base = np.where(is_weekend, 7000.0, 1500.0)
    base = base + is_holiday * 3000.0

    # 시간 가중
    hour_mul = np.array([_hour_factor(h) for h in hours])

    # 기온 가중 (22°C 이상적)
    temp_mul = 1.0 - (np.abs(temps - 22) / 60.0)
    temp_mul = np.where((temps < 10) | (temps > 30), temp_mul * 0.7, temp_mul)
    temp_mul = temp_mul.clip(0.3, 1.1)

    # 강수 가중
    rain_mul = np.where(rain_prob >= 70, 0.4,
                        np.where(rain_prob >= 50, 0.6, 1.0))

    # 이벤트 / 사전판매
    event_add = is_event * 1500
    presales_add = pre_sales * 0.7

    visitor = base * hour_mul * temp_mul * rain_mul + event_add + presales_add
    # 노이즈
    visitor = visitor * (1 + rng.normal(0, NOISE_PCT, size=n))
    visitor = np.clip(visitor, 50, 20000)

    df = pd.DataFrame({
        "hour":        hours.astype(int),
        "weekday":     weekdays.astype(int),
        "is_holiday":  is_holiday.astype(int),
        "temp":        temps.astype(float),
        "rain_prob":   rain_prob.astype(int),
        "is_event":    is_event.astype(int),
        "pre_sales":   pre_sales.astype(int),
        "visitor_count": visitor.astype(float),
    })
    return df


def main() -> int:
    rng = np.random.default_rng(SEED)
    df = _generate(N_SAMPLES, rng)
    print(f"generated {len(df)} synthetic samples")
    print(df.describe().round(1).to_string())

    X = df[config.FEATURE_ORDER]
    y = df["visitor_count"]

    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=0.2, random_state=SEED,
    )

    model = XGBRegressor(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.08,
        subsample=0.9,
        colsample_bytree=0.9,
        random_state=SEED,
        objective="reg:squarederror",
        verbosity=0,
    )
    model.fit(X_tr, y_tr)

    pred = model.predict(X_te)
    mae = mean_absolute_error(y_te, pred)
    r2 = r2_score(y_te, pred)
    print(f"\neval: MAE={mae:.0f}명  R²={r2:.3f}")
    if r2 < 0.7:
        print("⚠️ R² 가 낮습니다. 합성 데이터 룰을 다시 점검하세요.")

    config.MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, config.MODEL_PATH)
    print(f"\nsaved → {config.MODEL_PATH}")
    print(f"size: {config.MODEL_PATH.stat().st_size / 1024:.1f} KB")

    # 간단 sanity check — 평일 비 안 옴 vs 주말 맑음
    sample_low = pd.DataFrame([{
        "hour": 11, "weekday": 2, "is_holiday": 0, "temp": 5,
        "rain_prob": 80, "is_event": 0, "pre_sales": 100,
    }])[config.FEATURE_ORDER]
    sample_high = pd.DataFrame([{
        "hour": 14, "weekday": 6, "is_holiday": 0, "temp": 22,
        "rain_prob": 5, "is_event": 1, "pre_sales": 2500,
    }])[config.FEATURE_ORDER]
    print(f"\nsanity check:")
    print(f"  평일 비올 듯한 추운날 → {model.predict(sample_low)[0]:.0f}명 (기대: 하 등급)")
    print(f"  주말 맑은날 이벤트   → {model.predict(sample_high)[0]:.0f}명 (기대: 상 등급)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
