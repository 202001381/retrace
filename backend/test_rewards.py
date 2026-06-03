"""backend/rewards.py 단위 테스트 — Firestore 는 in-memory fake 로 대체.

전제:
  - 시즌 = autumn  (chapter targets = a01, a07, a12, a14, a08)
  - threshold 3 → goods, threshold 5 → ticket
"""

from __future__ import annotations

from datetime import date

import pytest

from . import rewards


# ─── In-memory Firestore 가짜 객체 ────────────────────────────────

class _FakeDoc:
    def __init__(self, ref, data):
        self.id = ref.id
        self._data = dict(data) if data else None

    @property
    def exists(self):
        return self._data is not None

    def to_dict(self):
        return dict(self._data) if self._data else None


class _FakeDocRef:
    def __init__(self, parent, doc_id):
        self.parent = parent
        self.id = doc_id

    def _key(self):
        return self.parent._key + (self.id,)

    def get(self, transaction=None):
        data = self.parent.store.get(self._key())
        return _FakeDoc(self, data)

    def set(self, data, *, merge=False):
        existing = self.parent.store.get(self._key()) if merge else None
        merged = {**(existing or {}), **data}
        # SERVER_TIMESTAMP sentinel 을 "now" 문자열로 대체.
        merged = {k: ("2026-09-15T09:00:00+09:00" if v == _SERVER_TS else v)
                  for k, v in merged.items()}
        self.parent.store[self._key()] = merged
        return None

    def update(self, data):
        existing = self.parent.store.get(self._key()) or {}
        merged = {**existing, **data}
        merged = {k: ("2026-09-15T09:00:00+09:00" if v == _SERVER_TS else v)
                  for k, v in merged.items()}
        self.parent.store[self._key()] = merged

    def collection(self, name):
        return _FakeCollection(self.parent.db, self._key() + (name,))


class _FakeCollection:
    def __init__(self, db, key):
        self.db = db
        self._key = key
        self.store = db.store

    def document(self, doc_id):
        return _FakeDocRef(self, doc_id)

    def stream(self):
        for k, v in self.store.items():
            if k[:-1] == self._key:
                yield _FakeDoc(_FakeDocRef(self, k[-1]), v)


class _FakeTransaction:
    """실제 Firestore Transaction 은 set/update/delete 를 ref 와 함께 받는다."""
    def set(self, ref, data, *, merge=False):
        ref.set(data, merge=merge)
    def update(self, ref, data):
        ref.update(data)


class _FakeDb:
    def __init__(self):
        self.store: dict[tuple, dict] = {}
        self.db = self

    def collection(self, name):
        return _FakeCollection(self, (name,))

    def transaction(self):
        return _FakeTransaction()


# firebase_admin.firestore.SERVER_TIMESTAMP / @fs.transactional 대체.
_SERVER_TS = object()


class _FakeFs:
    SERVER_TIMESTAMP = _SERVER_TS

    @staticmethod
    def transactional(fn):
        def wrapper(transaction, ref, *args, **kwargs):
            return fn(transaction, ref, *args, **kwargs)
        return wrapper


@pytest.fixture(autouse=True)
def _patch_firestore(monkeypatch):
    """firebase_admin.firestore 모듈 자체를 fake 로 교체.

    rewards.py 안에서 `from firebase_admin import firestore as fs` 가
    함수 내부에서 import 되므로 sys.modules 에 주입.
    """
    import sys, types
    fake_module = types.ModuleType("firebase_admin")
    fake_module.firestore = _FakeFs
    monkeypatch.setitem(sys.modules, "firebase_admin", fake_module)


@pytest.fixture
def db():
    return _FakeDb()


def _add_easter_egg(db, uid: str, attraction_id: str):
    ref = db.collection("users").document(uid).collection("easterEggs").document(attraction_id)
    ref.set({"discovered_at": "2026-09-15T09:00:00+09:00"})


# ─── 시즌 판정 ──────────────────────────────────────────────────

@pytest.mark.parametrize("month, expected", [
    (3, "spring"), (5, "spring"),
    (6, "summer"), (8, "summer"),
    (9, "autumn"), (11, "autumn"),
    (12, "winter"), (1, "winter"), (2, "winter"),
])
def test_current_season(month, expected):
    today = date(2026, month, 15)
    assert rewards.current_season(today) == expected


# ─── 챕터 진행도 ──────────────────────────────────────────────

def test_count_unlocked_books_partial(db):
    """가을 챕터 3개 중 2개만 발견 — count=2."""
    _add_easter_egg(db, "u1", "a01")  # autumn target
    _add_easter_egg(db, "u1", "a07")  # autumn target
    _add_easter_egg(db, "u1", "a99")  # autumn 아님
    assert rewards.count_unlocked_books("u1", "autumn", db=db) == 2


def test_count_unlocked_books_zero_for_other_season(db):
    """봄 챕터에 가을 발견은 카운트 안됨."""
    _add_easter_egg(db, "u1", "a01")
    assert rewards.count_unlocked_books("u1", "spring", db=db) == 0


# ─── 발급 흐름 ─────────────────────────────────────────────────

def _autumn_eggs(db, uid: str, n: int):
    """가을 챕터 첫 n개 어트랙션을 발견 처리."""
    for aid in rewards.CHAPTER_TARGETS["autumn"][:n]:
        _add_easter_egg(db, uid, aid)


def test_grant_nothing_below_threshold(db):
    _autumn_eggs(db, "u1", 2)  # 3 미만
    result = rewards.check_and_grant("u1", today=date(2026, 9, 15), db=db)
    assert result["unlocked_count"] == 2
    assert result["newly_granted"] == []
    assert result["already_granted"] == []


def test_grant_goods_at_3(db):
    _autumn_eggs(db, "u1", 3)
    result = rewards.check_and_grant("u1", today=date(2026, 9, 15), db=db)
    assert result["unlocked_count"] == 3
    assert len(result["newly_granted"]) == 1
    g = result["newly_granted"][0]
    assert g["type"] == "goods"
    assert g["threshold"] == 3
    assert g["season"] == "autumn"
    assert g["reward_id"] == "autumn_3"
    assert g["code"].startswith("DEMO-u1-autumn_3")


def test_grant_both_at_5(db):
    _autumn_eggs(db, "u1", 5)
    result = rewards.check_and_grant("u1", today=date(2026, 9, 15), db=db)
    assert result["unlocked_count"] == 5
    types_granted = sorted(r["type"] for r in result["newly_granted"])
    assert types_granted == ["goods", "ticket"]


def test_idempotent_grant(db):
    """두 번 호출해도 중복 발급 없음."""
    _autumn_eggs(db, "u1", 5)
    r1 = rewards.check_and_grant("u1", today=date(2026, 9, 15), db=db)
    assert len(r1["newly_granted"]) == 2
    r2 = rewards.check_and_grant("u1", today=date(2026, 9, 15), db=db)
    assert r2["newly_granted"] == []
    assert len(r2["already_granted"]) == 2


# ─── 조회 / 사용 ────────────────────────────────────────────────

def test_list_rewards_sorted(db):
    _autumn_eggs(db, "u1", 5)
    rewards.check_and_grant("u1", today=date(2026, 9, 15), db=db)
    items = rewards.list_rewards("u1", db=db)
    assert len(items) == 2
    assert {i["reward_id"] for i in items} == {"autumn_3", "autumn_5"}


def test_redeem_sets_redeemed_at(db):
    _autumn_eggs(db, "u1", 3)
    rewards.check_and_grant("u1", today=date(2026, 9, 15), db=db)
    updated = rewards.redeem_reward("u1", "autumn_3", db=db)
    assert updated is not None
    assert updated["redeemed_at"] is not None


def test_redeem_missing_returns_none(db):
    assert rewards.redeem_reward("u1", "spring_3", db=db) is None


def test_redeem_already_used_keeps_first_timestamp(db):
    _autumn_eggs(db, "u1", 3)
    rewards.check_and_grant("u1", today=date(2026, 9, 15), db=db)
    first = rewards.redeem_reward("u1", "autumn_3", db=db)
    again = rewards.redeem_reward("u1", "autumn_3", db=db)
    assert first["redeemed_at"] == again["redeemed_at"]
