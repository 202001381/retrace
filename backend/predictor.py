"""XGBoost 회귀 모델 래퍼.

학습된 모델은 joblib.dump 형식으로 config.MODEL_PATH 에 저장되어 있어야 한다.
예측값(일일 입장객 수)을 임계치 기반으로 혼잡도 등급(상/중/하)으로 변환한다.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

import joblib
import numpy as np
import pandas as pd

from . import config

CrowdLevel = Literal["상", "중", "하"]

_model = None


def _load_model():
    global _model
    if _model is None:
        if not config.MODEL_PATH.exists():
            raise FileNotFoundError(
                f"trained model not found at {config.MODEL_PATH}. "
                "joblib.dump(model, MODEL_PATH) 형식으로 저장하세요."
            )
        _model = joblib.load(config.MODEL_PATH)
    return _model


@dataclass(frozen=True)
class Prediction:
    visitor_count: float
    crowd_level: CrowdLevel


def to_crowd_level(visitor_count: float) -> CrowdLevel:
    if visitor_count <= config.CROWD_THRESHOLDS["low_max"]:
        return "하"
    if visitor_count <= config.CROWD_THRESHOLDS["mid_max"]:
        return "중"
    return "상"


def predict_one(features: dict) -> Prediction:
    """단일 샘플 예측. features 는 config.FEATURE_ORDER 의 키를 포함해야 한다."""
    model = _load_model()
    row = [features[k] for k in config.FEATURE_ORDER]
    X = pd.DataFrame([row], columns=config.FEATURE_ORDER)
    pred = float(np.asarray(model.predict(X)).ravel()[0])
    pred = max(0.0, pred)
    return Prediction(visitor_count=pred, crowd_level=to_crowd_level(pred))


def predict_batch(rows: list[dict]) -> list[Prediction]:
    model = _load_model()
    X = pd.DataFrame([[r[k] for k in config.FEATURE_ORDER] for r in rows], columns=config.FEATURE_ORDER)
    preds = np.asarray(model.predict(X)).ravel()
    return [Prediction(visitor_count=max(0.0, float(p)), crowd_level=to_crowd_level(p)) for p in preds]
