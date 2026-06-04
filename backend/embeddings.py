"""사용자·어트랙션 임베딩 — 룰 기반 점수에 의미 유사도 추가.

51개 어트랙션 풀에서 첫 스팟이 4종류 정도밖에 안 나오는 변별력 부족
문제를 해결하기 위해, 각 어트랙션과 사용자 선호를 같은 N차원 벡터로
표현하고 코사인 유사도를 점수에 결합.

룰 점수만 쓰던 시절: 같은 의도 두 사용자가 거의 같은 동선.
임베딩 점수 결합: 미세 변수까지 반영 + 매 호출 stochastic 샘플링으로
동일 입력에도 살짝 다른 동선이 나옴 (사용자가 "내 거" 라고 느끼게).

차원 (10):
  thrill          (0-1)  스릴 강도 (어트랙션: thrill_level/5)
  family          (0-1)  가족 친화도 (저 thrill + indoor 가중)
  photo           (0-1)  포토 매력 (category=포토스팟 + rating)
  food            (0-1)  식사 (category=음식점)
  cafe            (0-1)  카페·디저트
  easter_egg      (0-1)  스토리/이스터에그
  indoor          (0-1)  실내 (날씨 영향 X)
  popular         (0-1)  rating/5 (인기도)
  excitement      (0-1)  thrill 또는 큰 어트랙션
  calm            (0-1)  여유·힐링 (저 thrill + 평점 + outdoor)
"""

from __future__ import annotations

import math


_DIM = 10


def embed_attraction(a: dict) -> list[float]:
    """어트랙션 → 10차원 벡터. 카탈로그의 정적 속성으로 결정."""
    cat = a.get("category", "")
    thrill = a.get("thrill_level", 0) / 5.0
    rating = a.get("rating", 4.0) / 5.0
    indoor = 1.0 if a.get("indoor") else 0.0
    has_egg = 1.0 if a.get("has_easter_egg") else 0.0

    is_attr = cat == "어트랙션"
    is_food = cat == "음식점"
    is_cafe = cat == "카페"
    is_photo = cat == "포토스팟"

    return [
        thrill if is_attr else 0.0,                                  # thrill
        ((1 - thrill) * (0.6 if is_attr else 0.0) + 0.4 * indoor)
            if is_attr else 0.2,                                     # family
        rating if is_photo else (0.3 if is_attr else 0.1),           # photo
        rating if is_food else 0.0,                                  # food
        rating if is_cafe else 0.0,                                  # cafe
        has_egg,                                                     # easter_egg
        indoor,                                                      # indoor
        rating,                                                      # popular
        (thrill * 0.7 + rating * 0.3) if is_attr else 0.0,           # excitement
        ((1 - thrill) * 0.6 if is_attr else 0.0)
            + (0.5 if is_photo else 0.0)
            + (0.3 if is_cafe else 0.0),                             # calm
    ]


def embed_user(
    *,
    favorite_type: str | None,
    purpose: str | None,
    has_child: bool,
    has_infant: bool,
    discovered_eggs_ratio: float = 0.0,
) -> list[float]:
    """온보딩 답 + 진행 상황 → 10차원 선호 벡터.

    discovered_eggs_ratio: 0=초보 (이스터에그 많이 매력), 1=마스터 (관심 ↓).
    """
    from .route import (
        FAVORITE_FAMILY,
        FAVORITE_THRILL,
        PURPOSE_DATE,
        PURPOSE_KIDS_OUTING,
        PURPOSE_PICNIC,
        PURPOSE_RIDES,
    )

    thrill = 0.5
    family = 0.5
    photo = 0.5
    food = 0.5
    cafe = 0.5
    egg = 1.0 - discovered_eggs_ratio  # 덜 발견했을수록 매력
    indoor = 0.4
    popular = 0.7
    excitement = 0.5
    calm = 0.5

    if favorite_type == FAVORITE_THRILL:
        thrill = 1.0
        excitement = 0.9
        calm = 0.2
        family = 0.2
    elif favorite_type == FAVORITE_FAMILY:
        thrill = 0.2
        family = 0.95
        calm = 0.7
        excitement = 0.3

    if purpose == PURPOSE_DATE:
        photo = 0.95
        cafe = 0.85
        indoor = 0.65  # 분위기
        calm = max(calm, 0.6)
    elif purpose == PURPOSE_PICNIC:
        photo = 0.85
        calm = 0.8
        indoor = 0.15
        food = 0.6
    elif purpose == PURPOSE_KIDS_OUTING:
        family = 1.0
        thrill = min(thrill, 0.25)
        calm = 0.75
    elif purpose == PURPOSE_RIDES:
        excitement = max(excitement, 0.9)
        thrill = max(thrill, 0.7)

    if has_child:
        family = max(family, 0.85)
        thrill = min(thrill, 0.4)
    if has_infant:
        thrill = 0.0
        family = 1.0
        excitement = 0.2

    return [thrill, family, photo, food, cafe, egg, indoor, popular, excitement, calm]


def cosine(u: list[float], v: list[float]) -> float:
    """0~1 정규화된 코사인 유사도. 두 벡터가 모두 음수 0+인 경우 (0~1 임베딩)
    결과도 0~1."""
    if len(u) != len(v):
        return 0.0
    dot = sum(a * b for a, b in zip(u, v))
    nu = math.sqrt(sum(a * a for a in u))
    nv = math.sqrt(sum(b * b for b in v))
    if nu == 0 or nv == 0:
        return 0.0
    return dot / (nu * nv)
