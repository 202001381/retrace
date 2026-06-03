"""POST /api/story — 어트랙션 ID + 언어로 서사 텍스트 반환 (로컬 JSON 캐시).

캐시 키는 attraction_id + language 조합 — 같은 어트랙션의 다국어 응답을 각각 보관.
Firestore 결제 풀리면 캐시 위치를 attractions/{id}/stories/{lang} 로 이전.
"""
import json
import os

from flask import Blueprint, jsonify, request

import repository
from auth import require_firebase_auth
from llm_client import generate_story
from schemas import StoryRequest, StoryResponse

story_bp = Blueprint("story", __name__)

_CACHE_DIR = "./cache/stories"


def _cache_path(attraction_id: str, language: str) -> str:
    return os.path.join(_CACHE_DIR, f"{attraction_id}.{language}.json")


def _load_cache(attraction_id: str, language: str) -> dict | None:
    path = _cache_path(attraction_id, language)
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def _save_cache(attraction_id: str, language: str, data: dict) -> None:
    os.makedirs(_CACHE_DIR, exist_ok=True)
    with open(_cache_path(attraction_id, language), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


@story_bp.post("")
@require_firebase_auth
def post_story():
    payload = StoryRequest.model_validate(request.get_json(silent=True) or {})

    attraction = repository.get_attraction(payload.attraction_id)
    if attraction is None:
        return jsonify({
            "error": {
                "code": "NOT_FOUND",
                "message": f"존재하지 않는 어트랙션: {payload.attraction_id}",
            }
        }), 404

    cached = _load_cache(payload.attraction_id, payload.language)
    if cached:
        return jsonify({"data": StoryResponse(
            attraction_id=payload.attraction_id,
            title=cached["title"],
            body=cached["body"],
            cached=True,
            model=cached.get("model", "unknown"),
            language=cached.get("language", payload.language),
        ).model_dump()})

    story = generate_story(attraction, language=payload.language)
    _save_cache(payload.attraction_id, payload.language, story)

    return jsonify({"data": StoryResponse(
        attraction_id=payload.attraction_id,
        title=story["title"],
        body=story["body"],
        cached=False,
        model=story["model"],
        language=story["language"],
    ).model_dump()})
