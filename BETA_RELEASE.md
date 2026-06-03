# Re-Trace Beta 출시 가이드

## 기능 상태 (2026-06-03)

### ✅ 정상 작동 — 외부 키 없이도

| 기능 | 위치 | 동작 |
|---|---|---|
| 온보딩 → 마이루나 동선 추천 | `POST /api/route` | 임베딩 기반 점수 + 상위 3 중 stochastic 샘플링 |
| GPS 변화 시 동선 재요청 | `reason=gps_moved` | 100m+ 이동 시 자동 |
| 조건 변경 시 동선 갱신 | `reason=profile_changed` | 사용자 의도 우선 rationale |
| 5분 주기 시점 재평가 | `reason=tick` | lock window 만료 후 |
| 어트랙션 카탈로그 51개 | `attractions.json` | extract_attractions.py 로 Flutter 동기화 |
| 다국어 (ko/en) | 311 키 | `LocaleService` 즉시 토글 |
| 이스터에그 발견 + 서사 | `POST /api/narrative` | Anthropic 없으면 룰 fallback (16 톤) |
| 루나 프라이싱 카드 | `GET /api/pricing/now` | 날씨 + 예측 + 할인 통합 |
| 마이루나 lock window | 10분 (config) | 변경 가능 |
| 분석 이벤트 로깅 | `AnalyticsService` | 콘솔 로그 (Firebase 옵션) |

### ⚙️ 외부 키 필요 — 베타 환경에서는 기본값 fallback

| 기능 | 키 | fallback |
|---|---|---|
| 기상청 실시간 날씨 | `KMA_SERVICE_KEY` | rain=30%, temp=20°C, 흐림 |
| Anthropic 서사 생성 | `ANTHROPIC_API_KEY` | 시즌+동행 룰 (1988년 개장 멘션) |
| XGBoost 혼잡 예측 | `artifacts/crowd_model.pkl` | wait 정적값 |
| FCM 푸시 | `secrets/firebase-admin.json` | 발송 안 함 (502 skipped) |
| Firestore 사용자 데이터 | `secrets/firebase-admin.json` | 로컬 SharedPreferences 만 사용 |

### 🚫 출시 블로커 (정식 출시 전 필수)

- **인증** — `uid='guest'` 5곳 하드코딩. Firebase Auth 도입
- **VWorld 지도 API 키** — `map_screen.dart:614` 하드코딩, 도메인 제한 등록
- **법무 검토** — 마케팅·위치 동의 모달 텍스트 (placeholder)

---

## 실행 (3분)

### 백엔드
```bash
cd backend
pip install -r requirements.txt   # 첫 1회
SCHEDULER_ENABLED=0 KMA_SERVICE_KEY=test python3 -m backend.app
```

### Flutter Chrome (가장 빠른 데모)
```bash
flutter clean && flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5001
```

### Flutter macOS Native
```bash
flutter run -d macos --dart-define=API_BASE_URL=http://localhost:5001
```

---

## 서브시스템 상태 확인

```bash
curl http://localhost:5001/healthz/full
```

응답:
```json
{
  "status": "ok",
  "subsystems": {
    "catalog":      { "status": "ok", "count": 51 },
    "predictor":    { "status": "ok" },
    "weather":      { "status": "missing", "detail": "KMA_SERVICE_KEY not configured" },
    "narrative_ai": { "status": "missing", "detail": "fallback to rule-based" },
    "firebase":     { "status": "missing", "detail": "credentials file not found" }
  }
}
```

`status: "ok"` 면 핵심 (route + pricing 기본) 동작. `"degraded"` 면 503 + 어떤 서브시스템이 문제인지 본문에 표시.

---

## 사용자 체크리스트

1. **온보딩** — 가족/스릴/아이 데리고 나들이 선택 → 완료
2. **마이루나 진입** → DevTools Console 에 `[myluna] _fetch start gen=1 reason=initial survey=스릴 어트랙션 위주/아이 데리고 나들이/3명`
3. **STOP 01 확인** — `first=lava_twister` 같은 스릴 어트랙션 (carousel 이면 가족 + 아이 보호 절충 발동)
4. **조건 변경 → 친구 + 사진·인생샷** → 새 fetch (`gen=2 reason=profile_changed`) → 첫 스팟이 photo spot 으로 변경
5. **홈 hero 카드** — 가격 카드의 할인% 가 `/api/pricing/now` 의 응답값과 일치
6. **이스터에그 어트랙션 탭** → "이야기 들어보기" → 1.4초 후 narrative 모달
7. **언어 토글** → English → 모든 UI chrome 즉시 영어
8. **지도 GPS 버튼** → 권한 요청 → 실제 위치 또는 정문 fallback

---

## 알려진 제약

| 항목 | 영향 | 우회 |
|---|---|---|
| `flutter` 가 컨테이너에 없음 | 로컬 정적 검사 불가 | 사용자 머신에서 `flutter analyze` |
| KMA API 도메인 제한 | dev 에서 실시간 날씨 X | `KMA_SERVICE_KEY` 진짜 키 등록 |
| Anthropic key 부재 | AI 서사 → 룰 fallback | `ANTHROPIC_API_KEY=sk-ant-...` |
| 마이루나 첫 fetch + 사용자 즉시 조건 변경 race | 이전 버그, race counter 로 해결 | — |
| 동선이 의도와 절충되는 경우 | 가족(아이) + 스릴 → 저 thrill 우대 | 의도된 안전 동작 |

---

## 회귀 방지 — CI

`backend/test_*.py` 73 케이스 통과 시 백엔드 정상.

핵심 회귀 테스트:
- `test_pricing_now_endpoint` — `/api/pricing/now` graceful fallback
- `test_narrative_fallback_when_no_api_key` — Anthropic 없이도 응답
- `test_pipeline_endpoint_graceful_skip` — 외부 키 없을 때 502 skipped (500 아님)
- `test_healthz_full_reports_subsystems` — 모니터링 surface
- `test_rain_prob_high_boosts_indoor_attractions` — 비 → 실내 가산
- `test_profile_changed_rationale_priority` — 사용자 의도 1순위

```bash
cd backend && python -m pytest -q
```

`73 passed in ~2s` 면 회귀 없음.
