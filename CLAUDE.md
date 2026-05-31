# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

이 저장소는 **서울랜드 방문객 앱**의 데모용 풀스택 프로젝트입니다. Flutter 앱 + Python/Flask 백엔드가 한 저장소에 있고, 둘 다 동작합니다.

---

## 응답 가이드

- 모든 답변은 **한국어**
- 코드 변경이 여러 모듈·DB 스키마·외부 통합에 걸치면 **반드시 plan을 먼저 제시**하고 승인 후 진행
- 새 의존성 추가, 새 외부 API 호출, 새 환경 변수 도입은 **사전 고지**
- 식별자(클래스/함수/파일명/DB 필드)는 영어, 주석·문서·UX 노출 문자열은 한국어

---

## 저장소 구조 (실제)

```
flutter_application_1/        ← Flutter 앱
├── lib/
│   ├── main.dart             SeoullandApp + BottomNavigationBar (3탭) 진입점
│   ├── config.dart           apiBaseUrl 상수 (개발 기본 http://localhost:8080)
│   ├── models.dart           응답 파싱용 데이터 클래스 (Pricing/Recommended/Story)
│   ├── api_client.dart       3개 엔드포인트 래퍼 + CORS·에러 처리
│   └── screens/
│       ├── dashboard_screen.dart    /api/pricing
│       ├── recommend_screen.dart    /api/recommend
│       └── story_screen.dart        /api/story
├── test/widget_test.dart     SeoullandApp 스모크 테스트 (BottomNav 3탭 렌더링)
├── pubspec.yaml              flutter, http ^1.2.0, cupertino_icons
├── android/ ios/ linux/ macos/ web/ windows/    플랫폼 폴더
│
└── backend/                  ← Python 백엔드
    ├── app.py                Flask + APScheduler 진입점, 라우트 등록
    ├── config.py             OS 환경변수 → dataclass Config
    ├── firestore_client.py   firebase_admin 초기화 + Firestore 싱글톤
    ├── weather_client.py     기상청 단기예보 → XGBoost 피처 변환
    ├── xgboost_model.py      학습된 모델 로드·예측 (0–100 스코어)
    ├── train_model.py        합성 데이터로 데모 모델 학습 → models/visit_value.json
    ├── llm_client.py         Anthropic Claude 래퍼 (키 없으면 자동 스텁)
    ├── fcm_sender.py         FCM multicast 발송 래퍼 (dry_run 지원)
    ├── jobs.py               refresh_weather_score / send_revisit_pushes
    ├── pricing.py            POST /api/pricing
    ├── recommend.py          POST /api/recommend
    ├── route.py              POST /api/route (GPS 동선 추천)
    ├── route_planner.py      route 그리디 휴리스틱 알고리즘
    ├── story.py              POST /api/story (로컬 JSON 캐시)
    ├── users.py              POST/GET /api/users/me/{fcm-token, easter-eggs, chronicle}
    ├── rewards.py            POST /api/rewards/check, GET /api/users/me/rewards (트랜잭션)
    ├── auth.py               @require_firebase_auth + @require_internal_job 데코레이터
    ├── repository.py         DATA_BACKEND env-var 디스패처
    ├── repository_mock.py    mock_data 그대로 노출
    ├── repository_firestore.py   동일 인터페이스, Firestore 쿼리
    ├── mock_data.py          어트랙션 18·부대시설 12·구역 4·혼잡도 4·할인 4·챕터 8 (서울랜드 기반)
    ├── seed_firestore.py     Firestore 초기 시드 (mock_data + 데모 사용자 3명 + chapters)
    ├── wsgi.py               gunicorn 진입점 (Cloud Run)
    ├── Dockerfile            python:3.13-slim + 모델 빌드 시 학습 + gunicorn
    ├── .gcloudignore         배포 빌드 컨텍스트에서 secrets·models·캐시 제외
    ├── requirements.txt
    └── models/visit_value.json   학습된 XGBoost 모델 (gitignore 대상)
```

원칙:
- `app.py(view)` → `pricing/recommend/story.py(blueprint)` → `repository.py` → `mock` 또는 `firestore` 단방향
- 외부 SDK/HTTP(`requests`, `firebase-admin`, `anthropic`)는 `*_client.py` 또는 전용 파일에 격리

---

## 기술 스택 (실제)

### 백엔드

- **언어/런타임**: Python 3.13 (`py -3.13` 런처로 실행 — 기본 `python`은 3.8이라 사용 금지)
- **프레임워크**: Flask 3
- **개발 서버**: `python app.py` (Flask dev server)
- **운영 서버**: `gunicorn -w 2 -k gthread --threads 4 wsgi:app` (Cloud Run Dockerfile 안에서)
- **스케줄러**: **Cloud Scheduler** 가 외부에서 `/internal/jobs/*` 를 호출 (매일 07:00 / 22:00 KST). APScheduler 미사용.
- **검증/스키마**: Pydantic v2 (요청/응답 스키마, `extra='forbid'`)
- **DB**: Cloud Firestore Native 모드 (region `asia-northeast3`)
- **LLM**: Anthropic Claude (`claude-haiku-4-5`)
- **푸시**: Firebase Cloud Messaging (firebase-admin)
- **날씨**: 기상청 단기예보 (`apis.data.go.kr/.../VilageFcstInfoService_2.0`)
- **ML**: XGBoost 2.x (회귀 모델, 합성 데이터 학습 — Dockerfile 빌드 시 1회 실행)
- **HTTP 클라이언트(out)**: `requests` 라이브러리
- **CORS**: `flask-cors` (개발용 전체 허용)
- **로깅**: 표준 `logging` → Cloud Logging 자동 수집 (운영)
- **패키지 매니저**: `pip` (`requirements.txt`)
- **배포**: **Cloud Run** (region `asia-northeast3`) + Cloud Build + Secret Manager + Cloud Scheduler
- **시크릿**: Secret Manager (`kma-api-key`, `anthropic-api-key`, `internal-job-token`)
- **테스트**: 아직 없음 (수동 `Invoke-RestMethod` 호출로 검증)

### 프론트엔드

- **Flutter**: Dart SDK `^3.11.5`, flutter_lints `^6.0.0`
- **HTTP**: `http: ^1.2.0`
- **상태관리**: `setState` + `FutureBuilder` (라이브러리 없음)
- **라우팅**: BottomNavigationBar 3탭 (별도 라우터 없음)
- **테스트**: 스모크 1건 (`widget_test.dart`)

### 미적용 (성장 시 도입 후보)

- **Firestore Security Rules** — 테스트 모드 (30일 후 자동 잠김 → 운영 데이터 들어가기 전 정비 필수)
- **Cloud Run OIDC service-to-service** — 현재 `/internal/jobs/*` 는 `X-Internal-Token` 평문 헤더로 보호. 더 보안 강화 시 OIDC 로 교체
- **Cloud Run IAM `allow-unauthenticated=false`** — 현재 누구나 호출 가능 (앱 자체에서 `@require_firebase_auth` 로 차단). 추가 보안 시 IAM 까지 거기
- **structlog**, **mypy --strict**, **ruff**, **flask-talisman**, **uv**
- **pytest** 테스트 스위트

---

## 시스템 아키텍처 (운영)

```
[Flutter 앱 (Chrome 또는 모바일)]
     │  HTTPS + Firebase ID Token (AUTH_REQUIRED=true 시)
     ▼
[Cloud Run: seoul-land-api (asia-northeast3)]
     │  └ Dockerfile + gunicorn 2 worker × 4 thread
     │  ┌──────────────► [Anthropic Claude]    /api/story·/api/route (로컬 JSON 캐시)
     │  ├──────────────► [기상청 단기예보]     /api/pricing + refresh_weather 잡
     │  ├──────────────► [Cloud Firestore]    repository_firestore
     │  ├──────────────► [FCM]                 send_revisit_pushes 잡
     │  └──────────────► [Secret Manager]      kma·anthropic·internal-job-token
     ▲
     │  X-Internal-Token 헤더
     │
[Cloud Scheduler (asia-northeast3)]
     ├─ refresh-weather-job  cron "0 7 * * *"   → POST /internal/jobs/refresh-weather
     └─ send-pushes-job      cron "0 22 * * *"  → POST /internal/jobs/send-pushes
```

### 로컬 개발 시

```
[Chrome (flutter run -d chrome)]
     │  http://localhost:8080
     ▼
[Flask dev server (python app.py)]   APScheduler 없음 — 잡은 PowerShell 로 수동 호출
```

---

## API 계약 (실제 구현됨)

| Method | Path | 동작 | 인증 |
|---|---|---|---|
| `GET`  | `/health` | `{status, firestore: ready|unavailable}` | 없음 |
| `POST` | `/api/pricing` | 날씨 + 적용 할인 + visit_value_score + 구역별 혼잡도 | `@require_firebase_auth` |
| `POST` | `/api/recommend` | 구성원 정보 → Top-3 어트랙션 | `@require_firebase_auth` |
| `POST` | `/api/route` | GPS·구성원·가용시간 → 순서가 매겨진 동선 + LLM 안내 | `@require_firebase_auth` |
| `POST` | `/api/story` | 어트랙션 ID → 제목·본문 (Claude or 스텁) | `@require_firebase_auth` |
| `POST` | `/api/users/me/fcm-token` | FCM 디바이스 토큰 등록·갱신 | `@require_firebase_auth` |
| `POST` | `/api/users/me/easter-eggs` | 이스터에그 발견 기록 (idempotent) | `@require_firebase_auth` |
| `GET`  | `/api/users/me/easter-eggs` | 발견 목록 + 진행률 | `@require_firebase_auth` |
| `GET`  | `/api/users/me/chronicle?season=` | 시즌별 챕터·책 상태 (이스터에그에서 derive) | `@require_firebase_auth` |
| `POST` | `/api/rewards/check` | 현재 시즌 책 권수 기반 리워드 발급 (트랜잭션) | `@require_firebase_auth` |
| `GET`  | `/api/users/me/rewards` | 보유 리워드 목록 | `@require_firebase_auth` |
| `POST` | `/internal/jobs/refresh-weather` | 기상청→XGBoost→Firestore | `@require_internal_job` |
| `POST` | `/internal/jobs/send-pushes` | 사용자 순회→FCM | `@require_internal_job` |

**인증 동작**:
- `@require_firebase_auth` — `AUTH_REQUIRED=true` 시 `Authorization: Bearer <Firebase ID Token>` 필수. false 시 (기본) 검증 skip + `g.current_user=None`.
- `@require_internal_job` — `INTERNAL_JOB_TOKEN` env 설정 시 `X-Internal-Token` 헤더 일치 필수. 미설정 시 경고 후 통과 (개발 단계 한정, 운영 배포 전 반드시 설정).
- 401 응답 포맷: `{"error": {"code": "MISSING_TOKEN"|"EXPIRED_TOKEN"|"INVALID_TOKEN"|"AUTH_ERROR"|"INVALID_INTERNAL_TOKEN", "message": "..."}}`

### 응답 포맷

- 성공: `{ "data": { ... } }`
- 실패: `{ "error": { "code": "...", "message": "..." } }`

### 요청 검증

```python
payload = SomeRequestSchema.model_validate(request.get_json(silent=True) or {})
```
**`request.get_json()` 직접 사용 금지** — 항상 Pydantic schema 통과.

---

## Firestore 데이터 모델 (현재 시드됨)

```
attractions/{id}         name, type, location {lat,lng}, zone_id, thrill_level, capacity, min_height_cm, stay_minutes
facilities/{id}          name, type(restaurant|restroom|photo_spot|entrance), location, stay_minutes, description?
zones/{id}               name
congestion/{zone_id}     level (0-5), updated_at
discounts/{id}           title, rate, active, condition {type, value}
chapters/{id}            name, season(spring|summer|autumn|winter), required_attraction_ids
valueScoreSnapshot/current   score, features, computedAt              ← 잡이 갱신
users/{uid}                          fcmToken, fcmPlatform?, fcmTokenUpdatedAt, lastVisitAt, hasIncompleteChapter
users/{uid}/easterEggs/{attraction_id}    found_at                    ← doc_id = attraction_id (자연 idempotent)
users/{uid}/rewards/{reward_id}           type(goods|ticket), threshold, season, granted_at, redeemed_at?, code
```

> 필드는 mock_data 와 1:1 매칭이라 mock ↔ firestore 전환 시 비즈니스 로직 무수정. 새 컬렉션 추가 시 `repository_mock.py` + `repository_firestore.py` 양쪽 동일 함수 시그니처 유지.

### 의도적으로 저장하지 않는 derived data

- **연대기 (chronicle)** — `users/{uid}/chronicle/{season}` 도큐먼트 미사용. `GET /api/users/me/chronicle` 호출 시점에 `easterEggs` × `chapters` 정의로 매번 derive. 데이터 정합성 문제 없고 트리거·동기화 코드 불필요.
- **스토리 캐시** — `attractions/{id}/stories/{story_id}` 미사용. 현재는 `backend/cache/stories/{attraction_id}.json` 로컬 파일 캐시. 멀티 인스턴스 배포 시 Firestore 로 이전 필요.

---

## 환경 변수 (실제 필요)

`Flask 기동 시점에` 다음이 OS env에 있어야 함:

| 이름 | 용도 | 비고 |
|---|---|---|
| `KMA_API_KEY` | 기상청 단기예보 서비스키 (Decoding) | 필수 |
| `KMA_NX`, `KMA_NY` | 격자 좌표 (기본 62, 122) | 선택 |
| `GCP_PROJECT_ID` | Firestore 프로젝트 **ID** (문자열, 번호 X) | 필수 |
| `GOOGLE_APPLICATION_CREDENTIALS` | service account JSON 경로 | 필수 |
| `ANTHROPIC_API_KEY` | Claude API 키 | 없으면 /api/story 스텁 응답 |
| `FCM_DRY_RUN` | `true` 면 실제 발송 안 함 | 데모 단계 권장 |
| `DATA_BACKEND` | `firestore`(기본) 또는 `mock` | 비상 전환용 |
| `AUTH_REQUIRED` | `true` 면 모든 `/api/*` 에 Firebase ID Token 필수, `false` 기본 | 프론트 호환을 위해 기본 false |
| `INTERNAL_JOB_TOKEN` | 설정 시 `/internal/jobs/*` 에 `X-Internal-Token` 헤더 검증 | 운영 전 반드시 설정 |
| `XGBOOST_MODEL_PATH` | 기본 `./models/visit_value.json` | 선택 |
| `TIMEZONE` | 기본 `Asia/Seoul` | 선택 |

> `firebase_admin` 은 `projectId` 를 SA JSON 의 `project_id` 에서 자동 감지함 ([backend/firestore_client.py](backend/firestore_client.py) 참조). `GCP_PROJECT_ID` 와 SA 의 project_id 가 다르면 SA 우선.

`.gitignore` 필수 항목: `secrets/`, `*.json` (SA), `.env*`, `__pycache__/`, `backend/models/`, `backend/cache/`.

---

## 자주 쓰는 명령어

```powershell
# === 백엔드 ===
cd backend

# 의존성
py -3.13 -m pip install -r requirements.txt

# 모델 학습 (최초 1회 또는 재학습 시)
py -3.13 train_model.py

# Firestore 시드 (최초 1회)
py -3.13 seed_firestore.py

# 개발 서버 (현재 창 점유 — Ctrl+C 종료)
py -3.13 app.py

# 검증용 호출 (다른 PowerShell 창)
Invoke-RestMethod -Method POST -Uri http://localhost:8080/api/pricing `
  -ContentType "application/json" -Body '{}' | ConvertTo-Json -Depth 5

# === 프론트엔드 (저장소 루트에서) ===
flutter pub get
flutter analyze
flutter test
flutter run -d chrome       # 가장 빠른 데모 (Windows 데스크탑은 VS C++ 도구 필요)

# === Firestore 콘솔 ===
# https://console.firebase.google.com/project/seoul-land-dev/firestore/data
```

PowerShell 창은 다음과 같이 분담:
- **창 1**: `py -3.13 app.py` — Flask 점유, 종료 시 Ctrl+C
- **창 2**: `flutter run -d chrome` — Flutter 점유, r=리로드 / R=재시작 / q=종료
- **창 3**: 트리거·시드·진단 단발 명령. 환경변수는 Flask에 필요한 것만 일부 (시드 시 `GCP_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS` 등)

---

## 코딩 컨벤션

- **타입 힌트**: 함수 시그니처에 가능한 한 모두 (mypy 강제는 아직 안 함)
- **Pydantic v2**: 요청/응답 스키마는 `BaseModel` + `model_config = ConfigDict(extra='forbid')`
- **얇은 view 함수**: 비즈니스 로직은 `pricing/recommend/story.py` 안에. view는 검증·서비스 호출·응답 매핑만
- **Repository 패턴**: Firestore/mock 접근은 `repository.py` 통해서만 (view 함수에서 `db.collection(...)` 직접 호출 금지)
- **에러 응답 통일**: `{"error": {"code": ..., "message": ...}}` 형태
- **명명**: `snake_case` (변수/함수/모듈), `PascalCase` (클래스), `SCREAMING_SNAKE_CASE` (상수)
- **import 순서**: 표준 → 서드파티 → 로컬
- **private**: `_` prefix
- **f-string** 사용. `%` 포맷 금지
- **mutable default arguments** 금지 (`def f(items=[])` X)
- **`print()` 디버깅 금지** — `logger = logging.getLogger(__name__)` 사용

---

## LLM 호출 원칙

- 사용자 요청 시점에 실시간 호출은 최소화. /api/story 는 첫 호출 시 Claude → 로컬 JSON 캐시. 이후 같은 어트랙션은 캐시 응답.
- ANTHROPIC_API_KEY 가 없으면 자동으로 스텁 문구 반환 ([backend/llm_client.py](backend/llm_client.py))
- 모델/버전을 응답에 같이 기록 (`model`, `version` 필드)
- 비용 제어: 캐시가 첫 방어선. 새 어트랙션이 늘면 사전 생성 배치 잡으로 이동 필요.

---

## 작업 흐름

- 새 엔드포인트: `schemas.py` → 비즈니스 로직 파일(`<name>.py`) → `app.py` 에 blueprint 등록 → 수동 호출로 검증
- 새 데이터 컬렉션: `mock_data.py` 추가 → `repository_mock.py`/`repository_firestore.py` 양쪽에 동일 함수 추가 → `seed_firestore.py` 에 적재 함수 추가
- 새 외부 API: 전용 `*_client.py` 래퍼 먼저, 다른 모듈은 추상화 통해서만 호출
- 새 의존성·환경변수·외부 API는 **사전 고지**

---

## 피해야 할 패턴

- view 함수에서 직접 Firestore 호출 (반드시 `repository` 경유)
- view 함수에서 `request.get_json()` 직접 사용 (반드시 Pydantic schema)
- 사용자 요청 처리 중 LLM 동기 호출 (캐시 우선)
- 환경 분기를 `if os.getenv("ENV") == "prod"` 산발 처리 (Config dataclass 로 통일)
- 사용자별 캐시 키에 `uid` 누락
- 예외를 `except Exception: pass` 로 삼킴
- `requests.Session`·Firestore·Anthropic Client 를 요청마다 새로 생성 (싱글톤 재사용)
- Pydantic 모델 우회한 `dict` 직접 반환 (검증·문서화 누락)
- Firestore Read 비용 무시한 풀스캔 (할인룰 4건 같은 소형은 OK, 대형은 쿼리 추가)
- 트랜잭션 없이 리워드 발급 (중복 발급 위험) — 추후 구현 시 `firestore.transactional`
- 백엔드 응답에 `data`/`error` 래퍼 없이 raw dict 반환

---

## Flutter 쪽 메모

- 백엔드 URL 은 [lib/config.dart](lib/config.dart) 의 `apiBaseUrl` 한 곳에서 관리. Android 에뮬레이터(`10.0.2.2`) / 실기기 / 운영(원격) 으로 갈 때 여기만 수정.
- 모든 백엔드 응답 파싱은 [lib/api_client.dart](lib/api_client.dart) 의 `_post` 가 자동 언래핑. `{"data": ...}` 정상, `{"error": ...}` 는 `ApiException` 으로 throw.
- 상태관리는 `setState` + `FutureBuilder` — 화면이 5개 이상 되거나 화면 간 상태 공유가 필요해질 때 Riverpod 검토.

---

## 배포·운영 (Cloud Run)

### 배포 한 줄

```powershell
cd backend
gcloud run deploy seoul-land-api `
  --source . `
  --region asia-northeast3 `
  --allow-unauthenticated `
  --memory 1Gi --cpu 1 --min-instances 0 --max-instances 2 --timeout 60 `
  --set-env-vars "GCP_PROJECT_ID=seoul-land-dev,DATA_BACKEND=firestore,AUTH_REQUIRED=false,FCM_DRY_RUN=true,TIMEZONE=Asia/Seoul,KMA_NX=62,KMA_NY=122" `
  --set-secrets "KMA_API_KEY=kma-api-key:latest,ANTHROPIC_API_KEY=anthropic-api-key:latest,INTERNAL_JOB_TOKEN=internal-job-token:latest"
```

빌드는 Cloud Build 가 `Dockerfile` 자동 감지, 약 5~10분 소요. 결과로 `Service URL` 출력.

### 런타임 토글 (한 줄)

```powershell
# 운영 인증 켜기
gcloud run services update seoul-land-api --region asia-northeast3 --update-env-vars AUTH_REQUIRED=true

# FCM 실제 발송 켜기
gcloud run services update seoul-land-api --region asia-northeast3 --update-env-vars FCM_DRY_RUN=false

# 새 리비전 강제 (SA 권한 다시 로드 등)
gcloud run services update seoul-land-api --region asia-northeast3 --update-env-vars=_=_
```

### Cloud Scheduler 잡

```powershell
$internalToken = gcloud secrets versions access latest --secret=internal-job-token

# 매일 07:00 KST
gcloud scheduler jobs create http refresh-weather-job `
  --location asia-northeast3 --schedule "0 7 * * *" --time-zone "Asia/Seoul" `
  --uri "$serviceUrl/internal/jobs/refresh-weather" --http-method POST `
  --headers "X-Internal-Token=$internalToken"

# 매일 22:00 KST
gcloud scheduler jobs create http send-pushes-job `
  --location asia-northeast3 --schedule "0 22 * * *" --time-zone "Asia/Seoul" `
  --uri "$serviceUrl/internal/jobs/send-pushes" --http-method POST `
  --headers "X-Internal-Token=$internalToken"

# 수동 트리거 (즉시 실행)
gcloud scheduler jobs run refresh-weather-job --location asia-northeast3

Remove-Variable internalToken
```

### IAM (Cloud Run 기본 SA)

```powershell
$projectNumber = gcloud projects describe seoul-land-dev --format="value(projectNumber)"
$sa = "$projectNumber-compute@developer.gserviceaccount.com"

gcloud projects add-iam-policy-binding seoul-land-dev --member="serviceAccount:$sa" --role="roles/secretmanager.secretAccessor"
gcloud projects add-iam-policy-binding seoul-land-dev --member="serviceAccount:$sa" --role="roles/datastore.user"
```

### Secret Manager 운영

```powershell
# 새 버전 발행 (키 로테이션)
$tmp = New-TemporaryFile; $tmpPath = $tmp.FullName
[System.IO.File]::WriteAllText($tmpPath, $newKeyValue)
gcloud secrets versions add kma-api-key --data-file=$tmpPath
Remove-Item $tmpPath -Force

# 새 버전 발행 후 Cloud Run 새 리비전을 띄워야 시크릿 재로드됨
gcloud run services update seoul-land-api --region asia-northeast3 --update-env-vars=_=_
```

### 로그·모니터링

```powershell
gcloud run services logs read seoul-land-api --region asia-northeast3 --limit 50

# 특정 패턴
gcloud run services logs read seoul-land-api --region asia-northeast3 --limit 100 `
  | Select-String "valueScoreSnapshot|ERROR|HTTP/1.1"
```

Firebase 콘솔의 Firestore Data 탭에서 `valueScoreSnapshot/current.computedAt` 이 매일 07:00 직후 갱신되는지 확인 → 운영 헬스체크.

---

## 보안 메모 (현재 상태)

- **Firebase Auth 코드 적용 완료** ([backend/auth.py](backend/auth.py)). 운영 Cloud Run 의 `AUTH_REQUIRED` 환경변수로 켜고 끔. 프론트 동료가 ID Token 부착 전까지는 `false` 유지.
- **내부 잡** `@require_internal_job` 적용 완료. 운영에서는 `INTERNAL_JOB_TOKEN` 시크릿이 Cloud Scheduler 헤더로 주입되어 검증. 더 강화 시 OIDC service-to-service 로 교체 가능.
- Firestore 는 테스트 모드 — 30일 후 자동 잠김. 실 사용자 데이터 들어가기 전 Security Rules 정비 필수.
- 운영 키는 모두 **Secret Manager** 에 보관 (`kma-api-key`, `anthropic-api-key`, `internal-job-token`). Cloud Run 이 `--set-secrets` 로 환경변수에 자동 주입. 로컬에서는 OS 환경변수.
- 코드/로그/git/채팅에 키 절대 노출 금지. 노출 의심 시 `gcloud secrets versions add` 로 새 버전 발행 + Cloud Run 새 리비전 강제.
