# RE-TRACE Backend

서울랜드 다이나믹 프라이싱(루나 프라이싱) 백엔드. Flask + XGBoost + 기상청 API + FCM.

## 설치

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # 값 채우기
```

필수 파일:
- `artifacts/crowd_model.pkl` — joblib.dump 형식의 학습된 XGBoost 회귀 모델
- `secrets/firebase-admin.json` — Firebase Admin SDK 서비스 계정 키
- `.env` — 기상청 인증키 + `ANTHROPIC_API_KEY`

## 실행

```bash
# Flask 개발 서버 (스케줄러 자동 시작)
python -m backend.app

# 스케줄러 비활성화 (API 테스트만)
SCHEDULER_ENABLED=0 python -m backend.app
```

## API

| Method | Path | Body / Query | Response |
|---|---|---|---|
| GET  | `/healthz` | — | `{status, time}` |
| GET  | `/healthz/full` | — | `{status, subsystems{catalog,predictor,weather,narrative_ai,firebase}}` |
| GET  | `/api/pricing/now` | — | `{discount_pct, crowd_level, rain_prob, weather, temp, reason, computed_at}` — 날씨+예측+할인 통합 |
| POST | `/api/discount` | `{crowd_level, rain_prob}` | `{crowd_level, rain_prob, discount_pct, reason}` |
| POST | `/api/score` | `{crowd_level, weather, weekday, is_holiday, discount_pct}` | `{score, breakdown, inputs}` |
| POST | `/api/predict` | 7개 피처 + `weather` (선택) | `{crowd_level, visitor_count, discount, score}` |
| POST | `/api/route` | `RouteRequest`(uid, lat, lng, has_gps, onboarding, completed_attraction_ids, discovered_eggs, request_reason) + 선택 `features` | `{route[{id,order,eta_min_from_prev}], total_min, rationale, computed_at, cache_key}` |
| POST | `/api/run-pipeline?target=today\|tomorrow` | — | 파이프라인 결과 + FCM 발송 (외부 키 없으면 502 skipped) |
| GET  | `/api/crowd-level?visitor_count=N` | — | 임계치 기반 등급 |
| POST | `/api/narrative` | `{attraction_id, companion_type, season, weather, visit_count}` | `{attraction_id, attraction_name, narrative}` — ANTHROPIC_API_KEY 없으면 룰 fallback |
| POST | `/api/revisit-push/run` | — | `{counts, sent}` (Firebase 없으면 502 skipped) |
| POST | `/api/rewards/check` | `{uid}` | `{season, unlocked_count, newly_granted[], already_granted[]}` — 시즌 챕터 3개 → goods, 5개 → ticket. 트랜잭션 idempotent 발급 |
| GET  | `/api/rewards/list?uid=...` | — | `{items[{reward_id,type,threshold,season,granted_at,redeemed_at,code}]}` |
| POST | `/api/rewards/redeem` | `{uid, reward_id}` | 갱신된 reward (`redeemed_at` 채움) |

### Narrative 디스크 캐시
같은 `(attraction_id, locale, season, companion_type)` 4-튜플 조합은 변동 없는 결과 — 한 번 생성된 서사는 `./cache/narratives/{sha1[:16]}.json` 으로 보관. 재호출 시 Claude API 호출 없이 즉시 반환. 캐시 위치 변경: `NARRATIVE_CACHE_DIR=…` env. 룰 기반 fallback 응답은 캐시 안 함 (룰은 즉시 생성 가능).

### FCM 다중 토큰 발송
`fcm.send_to_tokens(tokens, title, body, data=)` — 최대 500개 multicast. 개인 보상 알림 등에 사용. 토픽 발송과 별개.

### Beta 환경 — 외부 키 없이 동작

| 의존성 | 미설정 시 동작 |
|---|---|
| `KMA_SERVICE_KEY` | `/api/pricing/now` 는 기본값 (rain=30, temp=20, 흐림) 으로 fallback |
| `ANTHROPIC_API_KEY` | `/api/narrative` 는 룰 기반 fallback (season + companion 조합 8가지 톤) |
| `secrets/firebase-admin.json` | `/api/run-pipeline` 과 `/api/revisit-push/run` 만 502 skipped, 나머지 정상 |
| `artifacts/crowd_model.pkl` | `/api/route` 의 시점 wait 보정 안 됨 (정적 wait 사용), 그 외 정상 |

`GET /healthz/full` 로 서브시스템 상태 한번에 확인.

### 예시

```bash
# 할인율
curl -X POST localhost:5000/api/discount \
  -H 'Content-Type: application/json' \
  -d '{"crowd_level":"하","rain_prob":65}'
# → {"crowd_level":"하","rain_prob":65,"discount_pct":22,"reason":"한산 + 강수 우려"}

# 방문 가치 스코어
curl -X POST localhost:5000/api/score \
  -H 'Content-Type: application/json' \
  -d '{"crowd_level":"중","weather":"흐림","weekday":2,"is_holiday":false,"discount_pct":15}'
```

## 자동화 파이프라인

`backend/scheduler.py` 가 APScheduler 로 매일 세 번 실행:

| 시각 (KST) | 대상 | 동작 |
|---|---|---|
| 22:00 | 다음날 | 기상청 → XGBoost → 조건 충족 시 FCM (토픽) |
| 07:00 | 당일 | 동일 |
| 09:00 | 전체 유저 | 재방문 트리거 평가 → 우선순위 1개 FCM (토큰) |

다이나믹 프라이싱 토픽 발송 조건: `혼잡도 == "하"` OR `강수확률 >= 50%`.
재방문 트리거 우선순위: 계절 갱신일(3/1·6/1·9/1·12/1) > 30일+미완성 ≥ 1 > 14일+전부 미완성.

## 모델 평가 (Task 4)

```bash
python -m backend.evaluate \
  --data data/train.csv \
  --model artifacts/crowd_model.pkl \
  --target visitor_count \
  --out reports/
```

산출물:
- `reports/eval_metrics.json` — RMSE / MAE / R² / Accuracy / classification_report
- `reports/eval_pred_vs_actual.png` — 산점도 + 임계치 보조선

## 모듈 구조

```
backend/
  app.py             Flask 진입점 (엔드포인트 + 스케줄러 시작)
  config.py          env 로드 + 상수
  discount.py        혼잡도 등급 → 할인율
  score.py           방문 가치 스코어 0~100
  weather.py         기상청 동네예보 클라이언트
  predictor.py       XGBoost 래퍼 (joblib 로드)
  fcm.py             Firebase Admin → FCM 발송 (토픽/토큰)
  firestore_client.py Firestore Admin 래퍼
  pipeline.py        기상청 → 모델 → 할인/스코어 → 토픽 FCM
  revisit_push.py    유저 평가 → 우선순위 1개 토큰 FCM
  narrative.py       Claude API 서사 생성 (어트랙션별 history_text)
  scheduler.py       APScheduler (07:00 / 09:00 / 22:00 KST)
  evaluate.py        모델 성능 평가 + 그래프
```

## 보안

`.env`, `artifacts/`, `secrets/`, `reports/` 는 커밋 금지 (`.gitignore` 처리).
