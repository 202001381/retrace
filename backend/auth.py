"""인증 데코레이터.

require_firebase_auth — 사용자 엔드포인트 보호 (Firebase ID Token).
    AUTH_REQUIRED=false 면 검증 skip, g.current_user = None.
    AUTH_REQUIRED=true 면 Authorization: Bearer <id_token> 검증 후
    g.current_user = {"uid", "email"} 세팅.

require_internal_job — 내부 잡 엔드포인트 보호 (간단한 공유 토큰).
    INTERNAL_JOB_TOKEN env 설정 시 X-Internal-Token 헤더 검증.
    미설정 시 (개발) 경고 후 통과. Cloud Run 배포 시 OIDC 로 교체 필요.
"""
import logging
from functools import wraps

from firebase_admin import auth as firebase_auth
from flask import current_app, g, jsonify, request

log = logging.getLogger(__name__)


def _unauthorized(code: str, message: str):
    return jsonify({"error": {"code": code, "message": message}}), 401


def require_firebase_auth(view_func):
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        config = current_app.config["SEOULLAND_CONFIG"]
        if not config.auth_required:
            g.current_user = None
            return view_func(*args, **kwargs)

        header = request.headers.get("Authorization", "")
        if not header.startswith("Bearer "):
            return _unauthorized(
                "MISSING_TOKEN",
                "Authorization: Bearer <Firebase ID Token> 헤더가 필요합니다",
            )
        token = header[len("Bearer "):].strip()
        try:
            decoded = firebase_auth.verify_id_token(token)
        except firebase_auth.ExpiredIdTokenError:
            return _unauthorized("EXPIRED_TOKEN", "토큰이 만료되었습니다")
        except firebase_auth.RevokedIdTokenError:
            return _unauthorized("REVOKED_TOKEN", "취소된 토큰입니다")
        except firebase_auth.InvalidIdTokenError as e:
            log.warning("InvalidIdTokenError: %s", e)
            return _unauthorized("INVALID_TOKEN", "유효하지 않은 토큰입니다")
        except Exception as e:
            log.warning("토큰 검증 실패: %s", e)
            return _unauthorized("AUTH_ERROR", "인증 처리 중 오류가 발생했습니다")

        g.current_user = {
            "uid": decoded["uid"],
            "email": decoded.get("email"),
        }
        return view_func(*args, **kwargs)

    return wrapper


def require_internal_job(view_func):
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        config = current_app.config["SEOULLAND_CONFIG"]
        expected = config.internal_job_token
        if not expected:
            log.warning(
                "INTERNAL_JOB_TOKEN 미설정 — 내부 잡 무인증 통과 "
                "(개발 단계만 허용, 운영 배포 전 반드시 설정)"
            )
            return view_func(*args, **kwargs)

        provided = request.headers.get("X-Internal-Token", "")
        if provided != expected:
            return _unauthorized(
                "INVALID_INTERNAL_TOKEN",
                "X-Internal-Token 헤더가 일치하지 않습니다",
            )
        return view_func(*args, **kwargs)

    return wrapper
