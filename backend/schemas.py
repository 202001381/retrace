"""Pydantic 요청/응답 스키마.

CLAUDE.md 규칙: extra='forbid'로 엄격 검증, request.get_json() 직접 사용 금지.
"""
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

_STRICT = ConfigDict(extra="forbid")


# ──────────────── /api/pricing ────────────────

class PricingRequest(BaseModel):
    model_config = _STRICT
    visit_at: Optional[str] = None  # ISO 타임스탬프, 비우면 now(KST)


class WeatherInfo(BaseModel):
    condition: str  # sunny|cloudy|rainy|snowy
    temp_c: float


class DiscountInfo(BaseModel):
    id: str
    title: str
    rate: float


class PricingResponse(BaseModel):
    weather: WeatherInfo
    discounts: list[DiscountInfo]
    visit_value_score: int  # 0-100
    congestion_by_zone: dict[str, int]  # zone_id -> 0-5


# ──────────────── /api/recommend ────────────────

class RecommendMember(BaseModel):
    model_config = _STRICT
    age: int = Field(ge=0, le=120)
    thrill_pref: int = Field(ge=1, le=5)  # 1: 매우 약함, 5: 매우 강함
    has_kids_role: bool = False  # 어린이 동반 여부 표시용 (본인이 어른인지 여부와 별개)


class LatLng(BaseModel):
    model_config = _STRICT
    lat: float
    lng: float


class RecommendRequest(BaseModel):
    model_config = _STRICT
    members: list[RecommendMember] = Field(min_length=1)
    current_location: Optional[LatLng] = None


class RecommendedAttraction(BaseModel):
    id: str
    name: str
    score: float  # 0-100
    reason: str  # 한 줄 추천 이유


class RecommendResponse(BaseModel):
    top: list[RecommendedAttraction]


# ──────────────── /api/story ────────────────

class StoryRequest(BaseModel):
    model_config = _STRICT
    attraction_id: str


class StoryResponse(BaseModel):
    attraction_id: str
    title: str
    body: str
    cached: bool
    model: str  # 'claude-haiku-4-5' | 'stub' 등


# ──────────────── /api/route ────────────────

class RouteRequest(BaseModel):
    model_config = _STRICT
    members: list[RecommendMember] = Field(min_length=1)
    current_location: LatLng
    available_minutes: int = Field(default=240, ge=60, le=480)  # 1~8시간


class RouteStep(BaseModel):
    order: int
    poi_id: str
    name: str
    type: str  # attraction|restaurant|restroom|photo_spot|entrance
    location: LatLng
    travel_minutes: int
    wait_minutes: int
    stay_minutes: int
    arrival_minute_from_start: int  # 시작 후 N분에 도착
    score: float
    reason: str


class RouteResponse(BaseModel):
    steps: list[RouteStep]
    total_minutes: int
    available_minutes: int
    narrative: Optional[str] = None  # LLM 자연어 안내 (키 없으면 null)


# ──────────────── /api/users/me/fcm-token ────────────────

class FcmTokenRequest(BaseModel):
    model_config = _STRICT
    fcm_token: str = Field(min_length=10)
    platform: Optional[str] = None  # 'android'|'ios'|'web'


class FcmTokenResponse(BaseModel):
    status: str  # 'registered'


# ──────────────── /api/users/me/easter-eggs ────────────────

class EasterEggCreateRequest(BaseModel):
    model_config = _STRICT
    attraction_id: str


class EasterEggInfo(BaseModel):
    attraction_id: str
    name: str  # 어트랙션 이름 (UI 편의)
    found_at: str  # ISO 8601


class EasterEggListResponse(BaseModel):
    items: list[EasterEggInfo]
    found_count: int
    total_count: int  # 전체 어트랙션 수


# ──────────────── /api/users/me/chronicle ────────────────

class BookStatus(BaseModel):
    attraction_id: str
    name: str
    unlocked: bool
    found_at: Optional[str]


class ChapterStatus(BaseModel):
    chapter_id: str
    name: str
    season: str
    books: list[BookStatus]
    unlocked_count: int
    total_count: int


class ChronicleResponse(BaseModel):
    season: str
    chapters: list[ChapterStatus]
    total_unlocked: int
    total_books: int


# ──────────────── /api/rewards ────────────────

class RewardInfo(BaseModel):
    reward_id: str
    type: str  # 'goods'|'ticket'
    threshold: int
    season: str
    granted_at: str
    redeemed_at: Optional[str] = None
    code: Optional[str] = None


class RewardCheckResponse(BaseModel):
    season: str
    unlocked_count: int
    newly_granted: list[RewardInfo]
    already_granted: list[RewardInfo]


class RewardListResponse(BaseModel):
    items: list[RewardInfo]
