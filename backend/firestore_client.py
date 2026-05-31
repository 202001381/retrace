"""Firestore Admin 클라이언트 — Firebase Admin SDK 통합."""

from __future__ import annotations

import logging
from typing import Iterator

import firebase_admin
from firebase_admin import credentials, firestore

from . import config

logger = logging.getLogger(__name__)
_db = None


def _ensure_app() -> None:
    if firebase_admin._apps:
        return
    if not config.FIREBASE_CREDENTIALS_PATH.exists():
        raise FileNotFoundError(
            f"firebase admin credentials not found at {config.FIREBASE_CREDENTIALS_PATH}"
        )
    cred = credentials.Certificate(str(config.FIREBASE_CREDENTIALS_PATH))
    firebase_admin.initialize_app(cred)


def db():
    global _db
    if _db is None:
        _ensure_app()
        _db = firestore.client()
    return _db


def iter_users() -> Iterator[tuple[str, dict]]:
    """전체 users 문서 순회. (uid, data)"""
    for doc in db().collection("users").stream():
        yield doc.id, doc.to_dict() or {}


def get_user(uid: str) -> dict | None:
    snap = db().collection("users").document(uid).get()
    return snap.to_dict() if snap.exists else None


def get_attraction(attraction_id: str) -> dict | None:
    snap = db().collection("attractions").document(attraction_id).get()
    return snap.to_dict() if snap.exists else None
