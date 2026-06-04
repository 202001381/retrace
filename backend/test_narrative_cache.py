"""narrative.py 디스크 캐시 동작 테스트.

Claude API 호출은 모킹 — 캐시 hit/miss 로직만 검증.
"""

from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import patch

import pytest

from . import narrative


@pytest.fixture
def cache_dir(tmp_path, monkeypatch):
    d = tmp_path / "nc"
    monkeypatch.setattr(narrative, "_CACHE_DIR", d)
    return d


def _attraction_stub(name="회전목마"):
    return {"name": name, "history_text": "옛날 옛적 회전목마가 있었다."}


def _mock_anthropic_response(text: str):
    """anthropic.messages.create 응답을 흉내내는 객체."""
    class _Block:
        def __init__(self, t): self.text = t
    class _Resp:
        def __init__(self, t): self.content = [_Block(t)]
    return _Resp(text)


def test_cache_key_deterministic_for_same_inputs():
    k1 = narrative._cache_key("a01", "ko", "spring", "혼자")
    k2 = narrative._cache_key("a01", "ko", "spring", "혼자")
    assert k1 == k2


def test_cache_key_differs_on_any_input_change():
    base = narrative._cache_key("a01", "ko", "spring", "혼자")
    assert base != narrative._cache_key("a02", "ko", "spring", "혼자")
    assert base != narrative._cache_key("a01", "en", "spring", "혼자")
    assert base != narrative._cache_key("a01", "ko", "summer", "혼자")
    assert base != narrative._cache_key("a01", "ko", "spring", "가족")


def test_cache_miss_calls_anthropic_and_writes_cache(cache_dir, monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test")
    monkeypatch.setattr(narrative.firestore_client, "get_attraction",
                        lambda _id: _attraction_stub())
    fake_client = type("C", (), {})()
    fake_client.messages = type("M", (), {})()
    fake_client.messages.create = lambda **_: _mock_anthropic_response("새로 생성된 서사")
    monkeypatch.setattr(narrative, "_get_client", lambda: fake_client)

    out = narrative.generate_narrative(
        attraction_id="a01", companion_type="혼자",
        season="spring", weather="맑음", visit_count=1,
    )
    assert out.narrative == "새로 생성된 서사"
    assert list(cache_dir.glob("*.json")), "캐시 파일이 생성되어야 함"


def test_cache_hit_skips_anthropic(cache_dir, monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test")
    monkeypatch.setattr(narrative.firestore_client, "get_attraction",
                        lambda _id: _attraction_stub())

    # 캐시 미리 채움.
    key = narrative._cache_key("a01", "ko", "spring", "혼자")
    cache_dir.mkdir(parents=True, exist_ok=True)
    (cache_dir / f"{key}.json").write_text(json.dumps({
        "narrative": "캐시된 서사",
        "attraction_name": "회전목마",
    }, ensure_ascii=False), "utf-8")

    # _get_client 가 호출되면 실패시키도록 raise — 호출 자체가 일어나면 안 됨.
    def boom():
        raise AssertionError("Anthropic 이 호출되면 안 됨 — 캐시 hit 이어야 함")
    monkeypatch.setattr(narrative, "_get_client", boom)

    out = narrative.generate_narrative(
        attraction_id="a01", companion_type="혼자",
        season="spring", weather="맑음", visit_count=1,
    )
    assert out.narrative == "캐시된 서사"


def test_fallback_does_not_write_cache(cache_dir, monkeypatch):
    """ANTHROPIC_API_KEY 없으면 룰 기반 → 캐시 파일 생기지 않아야 함."""
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.setattr(narrative.firestore_client, "get_attraction",
                        lambda _id: _attraction_stub())

    out = narrative.generate_narrative(
        attraction_id="a01", companion_type="혼자",
        season="spring", weather="맑음", visit_count=1,
    )
    assert out.narrative  # 룰 기반 텍스트 존재
    assert not list(cache_dir.glob("*.json")), "fallback 은 캐시 안 함"


def test_anthropic_failure_does_not_write_cache(cache_dir, monkeypatch):
    """Anthropic 호출 실패 → fallback 텍스트, 캐시 안 됨."""
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test")
    monkeypatch.setattr(narrative.firestore_client, "get_attraction",
                        lambda _id: _attraction_stub())
    class _Boom:
        class messages:
            @staticmethod
            def create(**_):
                raise RuntimeError("API down")
    monkeypatch.setattr(narrative, "_get_client", lambda: _Boom())

    out = narrative.generate_narrative(
        attraction_id="a01", companion_type="혼자",
        season="spring", weather="맑음", visit_count=1,
    )
    assert out.narrative  # fallback 작동
    assert not list(cache_dir.glob("*.json"))


def test_different_locales_get_separate_cache(cache_dir, monkeypatch):
    """ko 와 en 은 다른 파일로 캐시."""
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test")
    monkeypatch.setattr(narrative.firestore_client, "get_attraction",
                        lambda _id: _attraction_stub())
    fake_client = type("C", (), {})()
    fake_client.messages = type("M", (), {})()
    calls = []
    def _create(**kw):
        calls.append(kw)
        return _mock_anthropic_response(f"resp_{len(calls)}")
    fake_client.messages.create = _create
    monkeypatch.setattr(narrative, "_get_client", lambda: fake_client)

    narrative.generate_narrative(
        attraction_id="a01", companion_type="혼자",
        season="spring", weather="맑음", visit_count=1, locale="ko",
    )
    narrative.generate_narrative(
        attraction_id="a01", companion_type="혼자",
        season="spring", weather="맑음", visit_count=1, locale="en",
    )
    assert len(calls) == 2, "다른 locale 은 별도 호출"
    assert len(list(cache_dir.glob("*.json"))) == 2
