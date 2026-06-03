"""데모용 합성 데이터로 XGBoost 회귀 모델 학습.

실 운영에서는 과거 방문/예약/날씨 결합 데이터셋으로 재학습 필요.
실행: python train_model.py

명세(6.2 핵심 기술 스택)대로 scikit-learn 으로 80:20 train/test split 적용,
RMSE/MAE 평가 지표 출력.
"""
import math
import os

import numpy as np
import xgboost as xgb
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.model_selection import train_test_split

from xgboost_model import FEATURE_ORDER


def _synth_dataset(n: int = 5000, seed: int = 42):
    """합성 데이터 — 방문 가치 스코어(0–100).

    규칙(데모용):
    - 강수·강풍·고온/저온 → 점수 감소
    - 적정 기온(약 20°C)·주말 → 점수 증가
    """
    rng = np.random.default_rng(seed)
    temp = rng.uniform(-5, 35, n)
    humidity = rng.uniform(20, 100, n)
    precip = rng.choice([0, 0, 0, 0, 1, 5, 15], n).astype(float)
    wind = rng.uniform(0, 12, n)
    sky = rng.choice([1, 3, 4], n).astype(float)
    pty = rng.choice([0, 0, 0, 1, 2, 3], n).astype(float)
    hour = rng.integers(8, 22, n).astype(float)
    dow = rng.integers(0, 7, n).astype(float)
    month = rng.integers(1, 13, n).astype(float)
    is_weekend = (dow >= 5).astype(float)

    score = (
        70.0
        - 4.0 * np.abs(temp - 20.0)
        - 2.0 * precip
        - 0.5 * (humidity - 50.0).clip(0, None)
        - 1.5 * wind
        - 5.0 * (sky == 4).astype(float)
        - 10.0 * (pty > 0).astype(float)
        + 8.0 * is_weekend
        + rng.normal(0, 4, n)
    ).clip(0, 100)

    X = np.column_stack(
        [temp, humidity, precip, wind, sky, pty, hour, dow, month, is_weekend]
    )
    return X, score


def train(output_path: str) -> None:
    X, y = _synth_dataset()

    # scikit-learn 으로 80:20 train/test split (명세 6.2 항목)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    print(f"데이터 분할 — train {len(X_train)}개 / test {len(X_test)}개 (80:20)")

    dtrain = xgb.DMatrix(X_train, label=y_train, feature_names=FEATURE_ORDER)
    dtest = xgb.DMatrix(X_test, label=y_test, feature_names=FEATURE_ORDER)
    params = {
        "objective": "reg:squarederror",
        "eta": 0.1,
        "max_depth": 5,
        "subsample": 0.8,
        "verbosity": 0,
    }
    booster = xgb.train(params, dtrain, num_boost_round=200)

    # 평가
    y_pred = booster.predict(dtest)
    rmse = math.sqrt(mean_squared_error(y_test, y_pred))
    mae = mean_absolute_error(y_test, y_pred)
    print(f"검증 — RMSE {rmse:.3f}  MAE {mae:.3f}  (점수 0–100 범위 기준)")

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    booster.save_model(output_path)
    print(f"모델 저장 완료: {output_path}")


if __name__ == "__main__":
    train(os.environ.get("XGBOOST_MODEL_PATH", "./models/visit_value.json"))
