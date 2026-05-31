"""학습된 XGBoost 모델 로드 + 추론.

FEATURE_ORDER는 train_model.py와 반드시 일치해야 한다.
"""
import os
from typing import Dict

import numpy as np
import xgboost as xgb

FEATURE_ORDER = [
    "temp_c",
    "humidity",
    "precip_mm",
    "wind_ms",
    "sky",
    "pty",
    "hour",
    "day_of_week",
    "month",
    "is_weekend",
]


class VisitValueModel:
    """방문 가치 스코어(0–100) 예측기."""

    def __init__(self, model_path: str):
        if not os.path.exists(model_path):
            raise FileNotFoundError(
                f"모델 파일 없음: {model_path}. 먼저 `python train_model.py` 실행."
            )
        self.booster = xgb.Booster()
        self.booster.load_model(model_path)

    def predict(self, features: Dict[str, float]) -> float:
        row = np.array([[features[k] for k in FEATURE_ORDER]], dtype=np.float32)
        dmatrix = xgb.DMatrix(row, feature_names=FEATURE_ORDER)
        raw = float(self.booster.predict(dmatrix)[0])
        return max(0.0, min(100.0, raw))
