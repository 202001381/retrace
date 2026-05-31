"""Firebase Admin SDK 초기화 + Firestore 클라이언트 싱글톤.

projectId 는 GOOGLE_APPLICATION_CREDENTIALS 가 가리키는 SA JSON 의 project_id 에서
자동 감지된다. GCP_PROJECT_ID 환경변수가 SA 와 다를 경우 환경변수보다 SA 가 우선 —
env var 오타에 면역.
"""
import firebase_admin
from firebase_admin import firestore

from config import Config

_db = None


def init_firebase(_config: Config) -> None:
    if not firebase_admin._apps:
        firebase_admin.initialize_app()


def get_db():
    global _db
    if _db is None:
        _db = firestore.client()
    return _db
