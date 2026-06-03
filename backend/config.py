"""환경변수 로드.

.env 파일 사용하지 않음. OS 환경변수만 사용.
"""
from dataclasses import dataclass
from typing import Optional
import os


@dataclass(frozen=True)
class Config:
    kma_api_key: str
    kma_nx: int
    kma_ny: int
    kma_base_url: str

    gcp_project_id: str
    xgboost_model_path: str

    fcm_dry_run: bool
    timezone: str

    # 인증
    auth_required: bool  # true 면 /api/* 에 Firebase ID Token 필수
    internal_job_token: Optional[str]  # 설정 시 /internal/jobs/* 에 X-Internal-Token 헤더 검증

    # LLM
    llm_model: str  # Claude 모델 ID (예: claude-sonnet-4-6, claude-haiku-4-5)


def _required(key: str) -> str:
    value = os.environ.get(key)
    if not value:
        raise RuntimeError(f"환경변수 누락: {key}")
    return value


def load_config() -> Config:
    return Config(
        kma_api_key=_required("KMA_API_KEY"),
        kma_nx=int(os.environ.get("KMA_NX", "62")),
        kma_ny=int(os.environ.get("KMA_NY", "122")),
        kma_base_url=os.environ.get(
            "KMA_BASE_URL",
            "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getVilageFcst",
        ),
        gcp_project_id=_required("GCP_PROJECT_ID"),
        xgboost_model_path=os.environ.get(
            "XGBOOST_MODEL_PATH", "./models/visit_value.json"
        ),
        fcm_dry_run=os.environ.get("FCM_DRY_RUN", "false").lower() == "true",
        timezone=os.environ.get("TIMEZONE", "Asia/Seoul"),
        auth_required=os.environ.get("AUTH_REQUIRED", "false").lower() == "true",
        internal_job_token=os.environ.get("INTERNAL_JOB_TOKEN") or None,
        llm_model=os.environ.get("LLM_MODEL", "claude-sonnet-4-6"),
    )
