"""Flask 엔트리.

사용자 엔드포인트:
  POST /api/pricing      날씨·할인·방문가치 스코어·혼잡도 통합 응답
  POST /api/recommend    구성원 정보 기반 Top-3 어트랙션 추천
  POST /api/route        GPS·구성원·가용시간 기반 동선 추천
  POST /api/story        어트랙션 ID로 서사 텍스트 반환 (Claude or 스텁)
  POST/GET /api/users/me/...     FCM 토큰·이스터에그·연대기
  POST /api/rewards/check        리워드 발급 검사
  GET  /api/users/me/rewards     보유 리워드 목록

내부 잡 (Cloud Scheduler 가 외부에서 호출):
  POST /internal/jobs/refresh-weather   매일 07:00 KST
  POST /internal/jobs/send-pushes       매일 22:00 KST

운영(Cloud Run): gunicorn 으로 실행, Cloud Scheduler 가 시간 트리거 담당.
개발(로컬): `python app.py` 로 실행, 시간 트리거는 PowerShell 로 수동 호출.

Firestore 결제 활성화 전에는 init_firebase 가 실패할 수 있음 — 그 경우 사용자 엔드포인트는
정상 동작하고, 내부 잡 엔드포인트만 503 으로 응답하도록 graceful degradation 적용.
"""
import logging

from flask import Flask, jsonify
from flask_cors import CORS

from analytics import admin_stats_bp, events_bp
from auth import require_internal_job
from config import load_config
from firestore_client import get_db, init_firebase
from jobs import refresh_weather_score, send_revisit_pushes
from pricing import pricing_bp
from recommend import recommend_bp
from rewards import rewards_bp, users_rewards_bp
from route import route_bp
from story import story_bp
from users import users_bp
from xgboost_model import VisitValueModel

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)
log = logging.getLogger("seoulland.backend")


def _try_init_firestore(config):
    """Firestore 초기화 시도. 실패 시 None 반환하고 경고만 — 서버는 계속 기동."""
    try:
        init_firebase(config)
        return get_db()
    except Exception as e:
        log.warning(
            "Firestore 초기화 실패 — 사용자 엔드포인트는 동작, 내부 잡은 비활성: %s", e
        )
        return None


def create_app() -> Flask:
    config = load_config()
    model = VisitValueModel(config.xgboost_model_path)
    db = _try_init_firestore(config)

    app = Flask(__name__)
    # 개발용 — 모든 origin 허용. 운영 단계에서는 Flutter 도메인만 화이트리스트.
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    app.config["SEOULLAND_CONFIG"] = config
    app.config["SEOULLAND_MODEL"] = model
    app.config["SEOULLAND_DB"] = db

    app.register_blueprint(pricing_bp, url_prefix="/api/pricing")
    app.register_blueprint(recommend_bp, url_prefix="/api/recommend")
    app.register_blueprint(route_bp, url_prefix="/api/route")
    app.register_blueprint(story_bp, url_prefix="/api/story")
    app.register_blueprint(users_bp, url_prefix="/api/users")
    app.register_blueprint(users_rewards_bp, url_prefix="/api/users")
    app.register_blueprint(rewards_bp, url_prefix="/api/rewards")
    app.register_blueprint(events_bp, url_prefix="/api/events")
    app.register_blueprint(admin_stats_bp, url_prefix="/api/admin/stats")

    log.info("내부 잡(/internal/jobs/*)은 Cloud Scheduler 가 외부에서 호출")

    @app.get("/health")
    def health():
        return jsonify({
            "status": "ok",
            "firestore": "ready" if db is not None else "unavailable",
        })

    @app.post("/internal/jobs/refresh-weather")
    @require_internal_job
    def trigger_refresh():
        if db is None:
            return jsonify({"error": {"code": "FIRESTORE_UNAVAILABLE", "message": "Firestore 미초기화"}}), 503
        return jsonify(refresh_weather_score(config, model, db))

    @app.post("/internal/jobs/send-pushes")
    @require_internal_job
    def trigger_pushes():
        if db is None:
            return jsonify({"error": {"code": "FIRESTORE_UNAVAILABLE", "message": "Firestore 미초기화"}}), 503
        return jsonify(send_revisit_pushes(config, db))

    return app


if __name__ == "__main__":
    # 로컬 개발용. 운영(Cloud Run) 에서는 gunicorn 이 wsgi.py 의 app 을 호출.
    create_app().run(host="0.0.0.0", port=8080)
