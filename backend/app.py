"""Flask 진입점 — API 엔드포인트 + 스케줄러 시작.

엔드포인트:
  POST /api/discount  body: {crowd_level, rain_prob}            → 할인율
  POST /api/score     body: {crowd_level, weather, weekday, is_holiday, discount_pct} → 0~100
  POST /api/predict   body: {features...}                       → 전체 파이프라인 (수동 호출)
  POST /api/run-pipeline?target=today|tomorrow                  → 강제 실행 + FCM
  GET  /healthz
"""

from __future__ import annotations

import atexit
import logging
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from flask_cors import CORS

from . import config, discount, score
from .narrative import generate_narrative
from .pipeline import run_pipeline
from .predictor import predict_one, to_crowd_level
from .revisit_push import run_revisit_push
from .route import RouteRequest as RouteReq, recommend_route
from .scheduler import shutdown_scheduler, start_scheduler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


def create_app() -> Flask:
    app = Flask(__name__)
    # CORS — config.CORS_ORIGINS 이 "*" 면 전체 허용 (dev), 리스트면 화이트리스트 (prod).
    CORS(app, resources={r"/api/*": {"origins": config.CORS_ORIGINS},
                          r"/healthz": {"origins": "*"}})

    @app.get("/healthz")
    def healthz():
        return jsonify(status="ok", time=datetime.now(timezone.utc).isoformat())

    @app.post("/api/discount")
    def api_discount():
        body = request.get_json(force=True, silent=True) or {}
        try:
            result = discount.calc_discount(
                crowd_level=body["crowd_level"],
                rain_prob=float(body.get("rain_prob", 0)),
            )
        except (KeyError, ValueError) as e:
            return jsonify(error=str(e)), 400
        return jsonify(result)

    @app.post("/api/score")
    def api_score():
        body = request.get_json(force=True, silent=True) or {}
        try:
            result = score.calc_visit_value(
                crowd_level=body["crowd_level"],
                weather=body["weather"],
                weekday=int(body["weekday"]),
                is_holiday=bool(body.get("is_holiday", False)),
                discount_pct=float(body.get("discount_pct", 0)),
            )
        except (KeyError, ValueError) as e:
            return jsonify(error=str(e)), 400
        return jsonify(result)

    @app.post("/api/predict")
    def api_predict():
        """단발성 예측 (FCM 발송 안 함). features 전달 시 그대로 사용."""
        body = request.get_json(force=True, silent=True) or {}
        try:
            features = {k: body[k] for k in config.FEATURE_ORDER}
            pred = predict_one(features)
            rain = float(features["rain_prob"])
            weather_label = body.get("weather", "흐림")
            disc = discount.calc_discount(pred.crowd_level, rain)
            sc = score.calc_visit_value(
                crowd_level=pred.crowd_level,
                weather=weather_label,
                weekday=int(features["weekday"]),
                is_holiday=bool(features["is_holiday"]),
                discount_pct=disc["discount_pct"],
            )
        except (KeyError, ValueError, FileNotFoundError) as e:
            return jsonify(error=str(e)), 400

        return jsonify(
            crowd_level=pred.crowd_level,
            visitor_count=round(pred.visitor_count, 1),
            discount=disc,
            score=sc,
        )

    @app.post("/api/run-pipeline")
    def api_run_pipeline():
        target = request.args.get("target", "today")
        if target not in {"today", "tomorrow"}:
            return jsonify(error="target must be today|tomorrow"), 400
        try:
            result = run_pipeline(target)  # type: ignore[arg-type]
        except Exception as e:
            logger.exception("manual pipeline run failed")
            return jsonify(error=str(e)), 500
        return jsonify(result.to_dict())

    # 노출용 헬퍼 — Flutter 디버그에서 임의 visitor_count 로 등급 변환만 확인할 때
    @app.get("/api/crowd-level")
    def api_crowd_level():
        try:
            vc = float(request.args["visitor_count"])
        except (KeyError, ValueError):
            return jsonify(error="visitor_count query param required"), 400
        return jsonify(visitor_count=vc, crowd_level=to_crowd_level(vc))

    @app.post("/api/narrative")
    def api_narrative():
        body = request.get_json(force=True, silent=True) or {}
        try:
            out = generate_narrative(
                attraction_id=body["attraction_id"],
                companion_type=body.get("companion_type", "혼자"),
                season=body.get("season", "spring"),
                weather=body.get("weather", "맑음"),
                visit_count=int(body.get("visit_count", 1)),
            )
        except (KeyError, ValueError) as e:
            return jsonify(error=str(e)), 400
        except LookupError as e:
            return jsonify(error=str(e)), 404
        except Exception as e:
            logger.exception("narrative generation failed")
            return jsonify(error=str(e)), 500
        return jsonify(
            attraction_id=out.attraction_id,
            attraction_name=out.attraction_name,
            narrative=out.narrative,
        )

    @app.post("/api/route")
    def api_route():
        """동선 추천 — RouteRequest JSON → RouteResponse JSON.

        body.features 가 있으면:
          - predictor 로 시점 혼잡도(low/mid/high) 예측 → 어트랙션 wait 보정
          - rain_prob, hour, weekday, is_holiday 도 점수·rationale 에 반영
        모델 파일 없거나 predict 실패 시 정적 wait + features 만으로 fallback.
        """
        body = request.get_json(force=True, silent=True) or {}
        try:
            req = RouteReq.from_json(body)
        except (KeyError, ValueError, TypeError) as e:
            return jsonify(error=f"invalid request: {e}"), 400

        predicted_level: str | None = None
        rain_prob: float | None = None
        hour: int | None = None
        weekday: int | None = None
        is_holiday: bool | None = None

        pred_features = body.get("features") if isinstance(body, dict) else None
        if isinstance(pred_features, dict):
            # 점수·rationale 에 직접 쓰이는 시점 변수 추출 (모델과 별개로 항상 사용).
            try:
                rain_prob = float(pred_features.get("rain_prob")) if "rain_prob" in pred_features else None
            except (TypeError, ValueError):
                rain_prob = None
            try:
                hour = int(pred_features.get("hour")) if "hour" in pred_features else None
            except (TypeError, ValueError):
                hour = None
            try:
                weekday = int(pred_features.get("weekday")) if "weekday" in pred_features else None
            except (TypeError, ValueError):
                weekday = None
            try:
                is_holiday = bool(pred_features.get("is_holiday")) if "is_holiday" in pred_features else None
            except (TypeError, ValueError):
                is_holiday = None
            # AI 예측 — 모델 없으면 silently skip.
            try:
                features = {k: pred_features[k] for k in config.FEATURE_ORDER}
                pred = predict_one(features)
                predicted_level = pred.crowd_level
            except (KeyError, ValueError, FileNotFoundError) as e:
                logger.info("route predictor fallback: %s", e)

        try:
            resp = recommend_route(
                req,
                predicted_crowd_level=predicted_level,
                rain_prob=rain_prob,
                hour=hour,
                weekday=weekday,
                is_holiday=is_holiday,
            )
        except Exception as e:
            logger.exception("route recommendation failed")
            return jsonify(error=str(e)), 500
        return jsonify(resp.to_dict())

    @app.post("/api/revisit-push/run")
    def api_revisit_push_run():
        try:
            summary = run_revisit_push()
        except Exception as e:
            logger.exception("manual revisit push run failed")
            return jsonify(error=str(e)), 500
        return jsonify(summary)

    @app.get("/api/pricing/now")
    def api_pricing_now():
        """현재 시점의 루나 프라이싱 — 날씨 + 예측 + 할인 통합.

        내부에서:
          1. 기상청 동네예보 → 오늘 rain_prob, temp
          2. XGBoost predictor → crowd_level
          3. discount.calc_discount → 할인율

        Flutter 홈 hero 카드는 이 엔드포인트 한 방으로 모든 시점 데이터 받음.
        날씨 API 실패 / 모델 없음 시 graceful fallback (둘 다 기본값).
        """
        from datetime import datetime as _dt
        from . import weather as _weather
        from .predictor import predict_one as _predict_one

        now = _dt.now()
        rain_prob = 30.0
        temp = 20.0
        weather_label = "흐림"
        try:
            fcst = _weather.fetch_today()
            rain_prob = float(fcst.rain_prob)
            temp = float(fcst.temp_noon)
            weather_label = fcst.weather
        except Exception as e:
            logger.info("pricing weather fallback: %s", e)

        try:
            features = {
                "hour": now.hour,
                "weekday": now.weekday(),
                "is_holiday": 0,
                "temp": temp,
                "rain_prob": rain_prob,
                "is_event": 0,
                "pre_sales": 0,
            }
            pred = _predict_one(features)
            ko_level = pred.crowd_level
        except Exception as e:
            logger.info("pricing predict fallback: %s", e)
            ko_level = "중"

        result = discount.calc_discount(
            crowd_level=ko_level,
            rain_prob=rain_prob,
        )
        return jsonify({
            **result,
            "weather": weather_label,
            "temp": round(temp, 1),
            "computed_at": now.isoformat(),
        })

    if config.SCHEDULER_ENABLED:
        start_scheduler()
        atexit.register(shutdown_scheduler)
    else:
        logger.info("scheduler disabled by env")

    return app


if __name__ == "__main__":
    # 기본 5001 — macOS Monterey+ 의 AirPlay Receiver 가 5000 점유.
    # 다른 포트 쓰려면 `PORT=8000 python -m backend.app`
    import os
    port = int(os.environ.get("PORT", "5001"))
    create_app().run(host="0.0.0.0", port=port, debug=False)
