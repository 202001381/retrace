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
    congestion_grade: str  # '낮음' | '보통' | '혼잡'  (구역별 평균 → 등급 매핑)
    dynamic_discount_rate: float  # 0.0~0.30  (혼잡도 낮을수록 ↑, 수요 분산 인센티브)


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
    language: str = Field(default="ko", pattern="^(ko|en|ja|zh)$")  # 한·영·일·중


class StoryResponse(BaseModel):
    attraction_id: str
    title: str
    body: str
    cached: bool
    model: str  # 'claude-haiku-4-5' | 'stub' 등
    language: str  # 'ko' | 'en' | 'ja' | 'zh'


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


# ──────────────── /api/events ────────────────

_EVENT_TYPES = (
    "coupon_click",       # KPI 1: 쿠폰 클릭
    "ticket_purchase",    # KPI 1: 입장 전환
    "visit_arrive",       # KPI 2, 5: 어트랙션 도착
    "visit_leave",        # KPI 2: 어트랙션 떠남
    "attraction_select",  # KPI 5: 추천 후보 중 선택
    "coupon_redeem",      # KPI 4: 쿠폰 사용
    "fnb_purchase",       # KPI 4: F&B 결제 (객단가)
)


class EventCreateRequest(BaseModel):
    model_config = _STRICT
    type: str = Field(pattern="^(" + "|".join(_EVENT_TYPES) + ")$")
    properties: Optional[dict] = None  # 예: {coupon_id, attraction_id, amount, ...}


class EventCreateResponse(BaseModel):
    event_id: str
    type: str
    recorded_at: str


# ──────────────── /api/admin/stats/* ────────────────

class CouponFunnelStats(BaseModel):
    # KPI 1: Luna Pricing
    coupon_id: Optional[str] = None  # None 이면 전체 쿠폰 집계
    click_count: int
    purchase_count: int
    click_to_purchase_rate: float  # 클릭한 사용자 중 입장권 구매까지 간 비율


class RouteEffectivenessStats(BaseModel):
    # KPI 2: My Luna 동선
    recommended_group_avg_stay_min: float
    recommended_group_avg_attractions: float
    control_group_avg_stay_min: float
    control_group_avg_attractions: float
    sample_size_recommended: int
    sample_size_control: int


class EasterEggParticipationStats(BaseModel):
    # KPI 3: 이스터에그
    total_users: int
    participating_users: int  # 1개 이상 발견
    participation_rate: float
    chapter_completion: list[dict]  # [{chapter_id, name, avg_unlocked, total_books}]


class FnbStats(BaseModel):
    # KPI 4: F&B 쿠폰
    coupon_click_count: int
    coupon_redeem_count: int
    redemption_rate: float
    fnb_purchase_count: int
    avg_basket_size: float  # 객단가


class AttractionDistributionStats(BaseModel):
    # KPI 5: 추천 분산
    by_attraction: list[dict]  # [{attraction_id, name, visit_count, share}]
    top3_concentration: float  # 상위 3개 점유율
    alternative_selection_rate: float  # 추천 1위 외 선택 비율
