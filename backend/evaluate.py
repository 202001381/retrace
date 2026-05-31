"""Task 4 — XGBoost 회귀 모델 성능 평가.

사용법:
  python -m backend.evaluate --data data/train.csv --target visitor_count
  python -m backend.evaluate --data data/train.csv --model artifacts/crowd_model.pkl

필수 컬럼: config.FEATURE_ORDER 의 7개 피처 + target 컬럼
출력:
  - 콘솔: RMSE / MAE / R² / Accuracy / classification_report
  - 파일: reports/eval_metrics.json
  - 그래프: reports/eval_pred_vs_actual.png
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    mean_absolute_error,
    mean_squared_error,
    r2_score,
)
from sklearn.model_selection import train_test_split

from . import config
from .predictor import to_crowd_level

logger = logging.getLogger(__name__)


@dataclass
class EvalMetrics:
    n_train: int
    n_test: int
    rmse: float
    mae: float
    r2: float
    accuracy: float


def _to_levels(values: np.ndarray) -> list[str]:
    return [to_crowd_level(float(v)) for v in values]


def evaluate(
    data_path: Path,
    model_path: Path,
    target_col: str,
    output_dir: Path,
    test_size: float = 0.2,
    seed: int = 42,
) -> EvalMetrics:
    df = pd.read_csv(data_path)
    missing = [c for c in config.FEATURE_ORDER if c not in df.columns]
    if missing:
        raise ValueError(f"data missing required feature columns: {missing}")
    if target_col not in df.columns:
        raise ValueError(f"target column '{target_col}' not in data")

    X = df[config.FEATURE_ORDER]
    y = df[target_col].astype(float)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=test_size, random_state=seed
    )

    model = joblib.load(model_path)
    y_pred = np.asarray(model.predict(X_test)).ravel()

    rmse = float(np.sqrt(mean_squared_error(y_test, y_pred)))
    mae = float(mean_absolute_error(y_test, y_pred))
    r2 = float(r2_score(y_test, y_pred))

    y_test_lv = _to_levels(y_test.to_numpy())
    y_pred_lv = _to_levels(y_pred)
    acc = float(accuracy_score(y_test_lv, y_pred_lv))
    cls_report = classification_report(
        y_test_lv, y_pred_lv, labels=["상", "중", "하"], digits=3, zero_division=0
    )

    metrics = EvalMetrics(
        n_train=len(X_train),
        n_test=len(X_test),
        rmse=round(rmse, 3),
        mae=round(mae, 3),
        r2=round(r2, 4),
        accuracy=round(acc, 4),
    )

    output_dir.mkdir(parents=True, exist_ok=True)
    metrics_path = output_dir / "eval_metrics.json"
    metrics_path.write_text(
        json.dumps(
            {
                **asdict(metrics),
                "thresholds": config.CROWD_THRESHOLDS,
                "classification_report": cls_report,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    _plot_pred_vs_actual(
        y_test.to_numpy(),
        y_pred,
        out=output_dir / "eval_pred_vs_actual.png",
        title=f"Pred vs Actual (RMSE={rmse:.1f}, R²={r2:.3f})",
    )

    print("─" * 60)
    print(f"Train/Test: {metrics.n_train} / {metrics.n_test}")
    print(f"RMSE:       {metrics.rmse}")
    print(f"MAE:        {metrics.mae}")
    print(f"R²:         {metrics.r2}")
    print()
    print(f"혼잡도 분류 (임계치: {config.CROWD_THRESHOLDS})")
    print(f"Accuracy:   {metrics.accuracy}")
    print()
    print(cls_report)
    print("─" * 60)
    print(f"metrics → {metrics_path}")
    print(f"plot    → {output_dir / 'eval_pred_vs_actual.png'}")
    return metrics


def _plot_pred_vs_actual(actual: np.ndarray, pred: np.ndarray, out: Path, title: str) -> None:
    fig, ax = plt.subplots(figsize=(7, 7))
    ax.scatter(actual, pred, alpha=0.55, s=24, color="#E60012")
    lim_lo = float(min(actual.min(), pred.min()))
    lim_hi = float(max(actual.max(), pred.max()))
    ax.plot([lim_lo, lim_hi], [lim_lo, lim_hi], "--", color="#1E3158", linewidth=1.5)

    for thr in config.CROWD_THRESHOLDS.values():
        ax.axvline(thr, color="#AAAAAA", linestyle=":", linewidth=0.8)
        ax.axhline(thr, color="#AAAAAA", linestyle=":", linewidth=0.8)

    ax.set_xlabel("Actual visitor count")
    ax.set_ylabel("Predicted visitor count")
    ax.set_title(title)
    ax.grid(True, alpha=0.25)
    fig.tight_layout()
    fig.savefig(out, dpi=140)
    plt.close(fig)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Evaluate trained XGBoost crowd model")
    parser.add_argument("--data", required=True, type=Path, help="CSV with feature columns + target")
    parser.add_argument("--model", type=Path, default=config.MODEL_PATH)
    parser.add_argument("--target", default="visitor_count", help="target column name")
    parser.add_argument("--out", type=Path, default=Path("reports"))
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args(argv)

    evaluate(
        data_path=args.data,
        model_path=args.model,
        target_col=args.target,
        output_dir=args.out,
        test_size=args.test_size,
        seed=args.seed,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
