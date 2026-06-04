# Re·Trace 베타 검증 — 전수 점검 리포트

**점검 일자:** 2026-06-04
**점검 대상 브랜치:** `origin/feat/full-backend-stack`
**점검 방식:** 정적 코드 검사 (git show + grep + 파일 구조 분석)
**검증 도구:** 두 개 병렬 audit agent

---

## ⚠️ 점검의 한계 (먼저 읽어주세요)

### 가능했던 것
- 소스 파일 (`*.dart`, `*.py`, `*.arb`) 의 함수/위젯/엔드포인트 **존재 여부**
- 응답 구조·체크 분기·fallback 경로 **소스 레벨 검증**
- l10n 키 누락, 잘못된 디자인 토큰 사용 등 **정적 회귀**
- 시드 데이터 카운트, 토픽 명, 이벤트 카드 개수 등 **데이터 형상**

### 불가능했던 것
- 실제 백엔드 서버 실행 (`uvicorn`/`gunicorn` 실행 권한·네트워크 없음)
- 실제 HTTP 호출, DB·Firebase·Anthropic API 응답 검증
- 빌드 명령 (`flutter analyze`, `flutter test`, `flutter build`) 실행
- 런타임 동작 (애니메이션, 진동, 푸시 수신, 권한 다이얼로그)
- 시각적 검증 (디자인 픽셀 단위 일치 여부)
- 실기기 동작 (FCM 토큰 발급, GPS, OSRM 외부 호출)

→ 위 항목들은 **🔍 (런타임 검증 필요)** 마크. 사용자 머신에서 직접 실행해야 합니다.

---

## ⚠️ 핵심 결함 8개 — 출시 전 확정 처리 권장

| # | 위치 | 결함 | 근거 |
|---|---|---|---|
| 1 | § 3 지도 | **AI 스캔 FAB 미연결** | `ai_scan_modal.dart` 존재하지만 `map_screen.dart` 어디서도 호출 안 함 |
| 2 | § 3 지도 | 일반 "이스터에그 필터" 부재 | `map_screen.dart:919-924` "내 이스터에그" 토글만 |
| 3 | § 4 마이루나 | stop 탭 → 어트랙션 상세 가 아니라 **바로 네비 진입** | `myluna_screen.dart:506 onTap → _onNavigate` |
| 4 | § 2 홈 | 못 찾은 이스터에그 카운트 | 프라이싱 시트(`:1075`)에만 노출, MyLuna 카드엔 없음 |
| 5 | § 2 홈 | TODAY EVENTS 카드 **6개** (스펙 3) | `home_screen.dart:1559-1564` 불꽃놀이/콘서트/페이스페인팅 잉여 |
| 6 | § 8 마이페이지 | 이용약관/개인정보 처리방침 | `mypage_screen.dart:266-271` SnackBar placeholder 만, 실제 화면 없음 |
| 7 | § 12 푸시 | `all_users` 토픽 **미구독** | `fcm_service.dart:23, 94` 에 `luna_pricing` 만 |
| 8 | § 12 푸시 | 백그라운드 알림 탭 라우팅 **TODO** | `fcm_service.dart:130-138` log 만, "// TODO: 라우팅" 주석 |

---

## 섹션별 결과

### § 1 온보딩 — 8 / 8 ✅

| 항목 | 결과 | 근거 |
|---|---|---|
| B1 반짝이가 타이틀 위에 안 겹침 | ✅ | `onboarding_screen.dart:397` |
| B2 페이지 2/3 마이루나/프라이싱 카드 | ✅ | `:190-213` `_IntroExplainPage` |
| 설문1 카운터 0~20 | ✅ | `:161` `_members[c] = next.clamp(0, 20)` |
| 설문2 단일선택 (thrill/family/both) | ✅ | `:235-238` |
| 설문3 목적 4종 (rides/picnic/kidsOuting/date) | ✅ | `:249-252` |
| 결과 코스 라벨 + 요약 | ✅ | `:117-156` `_resultKind()`, `_summaryText()` |
| 건너뛰기 어디서든 → 홈 | ✅ | `:94` `_skipFromIntro`, 사용처 `:186/199/211/222` |
| Back 버튼 | ✅ | `:165-166` `_showBack` |

---

### § 2 홈 탭 — 8 ✅ / 2 ⚠️

| 항목 | 결과 | 근거 |
|---|---|---|
| 루나 프라이싱 ₩35K → ₩29.75K (-15%) | ✅ | `luna_pricing_service.dart:19` base, `home_screen.dart:907,918,937,959` UI |
| 만료 카운트다운 | ✅ | `home_screen.dart:1063` `DiscountCountdown` |
| 티켓 받기 → 체크아웃 | ✅ | `:401, 975` |
| 할인 사유 라벨 (이모지 + 텍스트) | ✅ | `:1063` `DiscountCauseLabel.reasonLabel` + `pricing.reasonEmoji` |
| 마이 루나 카드 — 마커 이모지 | ✅ | `:1492` `Stamp(emoji: item.emoji)` |
| 발견 안 한 이스터에그 N개 | ⚠️ | 프라이싱 시트(`:1075`)에만, MyLuna 카드 미노출 |
| 예상 소요 약 N분 | ✅ | `:1383` `home_route_total_min(totalMin!)` |
| 조건 변경 → 재추천 | ✅ | `:308-329` `_openSettingsSheet` → `_loadRoute('profile_changed')` |
| 새로고침 🔄 | ✅ | `:1318-1330` |
| 전체 동선 보기 → 마이루나 탭 | ✅ | `:1262` |
| TODAY EVENTS 3개 | ⚠️ | `:1559-1564` 실제 6개 정의 (불꽃놀이/콘서트/페이스페인팅 잉여) |

---

### § 3 지도 탭 — 9 ✅ / 1 ⚠️ / 1 ❌

| 항목 | 결과 | 근거 |
|---|---|---|
| VWorld 타일 | ✅ | `map_screen.dart:675` `api.vworld.kr/.../Base/{z}/{y}/{x}.png` |
| 마커 이모지 | ✅ | `:1266`, `myluna_navigate_screen.dart:239` |
| GPS 버튼 floating | ✅ | `:703-708` |
| 검색 pill | ✅ | `:990-1000` Icon + TextField + `map_search_hint` |
| 마커 탭 → 상세 시트 | ✅ | `:936` `onTap: () => _openDetail(a)` |
| 동선 ON → 폴리라인 | ✅ | `:685` `if (_showRoute) PolylineLayer(...)` |
| OSRM 단일 내비 | ✅ | `:600` `_fetchNavRoute` + `osrm_router.dart` |
| 카테고리 필터 4종 (어트랙션/음식점/카페/포토스팟) | ✅ | `:877` `PlaceCategory.values + 1 전체` |
| 이스터에그 + 내 이스터에그 (둘) | ⚠️ | "내 이스터에그" 만 (`:919-924`), 일반 이스터에그 필터 없음 |
| **AI 스캔 FAB** | ❌ | `ai_scan_modal.dart` 존재, `map_screen.dart` 미연결 |
| 시트 3단계 (0.12/0.50/0.92) | ✅ | `:80-82, 743` `snapSizes` |

---

### § 4 마이 루나 탭 — 10 ✅ / 1 ❌

| 항목 | 결과 | 근거 |
|---|---|---|
| 풀스크린 동선 카드 | ✅ | `myluna_screen.dart` main scaffold |
| stat row 도보 / 대기 / 총 | ✅ | `:738-748` `_StatCell walk/wait/total` |
| 데모 시나리오 칩 (가족/데이트/스릴 4시간) | ✅ | `demo_scenario.dart:12,32,52` |
| 타이밍 윈도우 30s / 5m ticker | ✅ | `myluna_screen.dart:75, 79` `Timer.periodic` |
| **stop 탭 → 어트랙션 상세** | ❌ | `:506 onTap: () => _onNavigate(e.value)` — 네비 화면으로 점프 |
| 지금 출발 → OSRM 풀스크린 네비 | ✅ | `:362-369` → `MyLunaNavigateScreen` |
| 큰 글자 거리 + 방향 | ✅ | `myluna_navigate_screen.dart:273` `_DistanceCard` |
| 도보 약 N분 | ✅ | `:153` `_walkMin` |
| 폴리라인 호수 우회 | ✅ | `osrm_router.dart:6, 118` PathGraph fallback |
| GPS 50m+ 재페치 | ✅ | `:88` `if (... < 50) return` |
| 목적지 50m 진입 SnackBar | ✅ | `:26, 103` `_kArrivalRadiusM = 50` |

---

### § 5 Archive — 13 / 13 ✅

전 항목 코드 검증 통과. mini spine 주석 (`28×96`) 만 stale — 실제 코드는 `width:32 height:96` 으로 스펙 일치.

| 항목 | 결과 | 근거 |
|---|---|---|
| RETRACE ARCHIVE eyebrow + 기억의 책장 2026 | ✅ | `archive_screen.dart:904, 934` |
| 🔍 검색 → bottomSheet → 책 매칭 | ✅ | `:552-557` `_openSearch` → `_ArchiveSearchSheet` |
| + 추가 → "수동 추가는 곧 열려요" SnackBar | ✅ | `:567-571`, `app_ko.arb:386` |
| 시즌 탭 4개 균등 + 활성 검정 + dot | ✅ | `:969-989` Expanded + `Color(0xFF111111)` + dotColor |
| tagline + 행사 N · M권 | ✅ | tagline `:106,124,142,160`; `app_ko.arb:370` |
| 봄 이벤트 (벚꽃/어린이날/플라워가든) | ✅ | `:218-241` 3 events |
| 여름/가을/겨울 각 3개 | ✅ | `:245-332` 3 each |
| mini spine 32×96 + 4자 + mono 날짜 | ✅ | `:1255 height:96, :1307 width:32, :1292 take(4)` |
| 점선 placeholder "다음 행사 칸" | ✅ | `:1359-1387` `_NextEventPlaceholder` |
| 시즌 보상 진행도 (X/5 + 임계점 + 코드보기 3+) | ✅ | `:2927+`, `:3052 reward_action_view_code` |
| 통계 카드 (수집/사진/챕터) | ✅ | `:2820` |
| 책 탭 → 풀스크린 다이얼로그 3장 | ✅ | `:1718 Dialog.fullscreen, :1738 itemCount:3` |
| 메모리 페이지 사진 갤러리/촬영 → 저장 유지 | ✅ | `:1668-1687 _pickPhoto` + `_PhotoStore.setPhoto` |

---

### § 6 보상 — 9 ✅ / 1 🔍

| 항목 | 결과 | 근거 |
|---|---|---|
| 챕터 3 → 풀스크린 진동 모달 (heavyImpact) | ✅ | `reward_controller.dart:55-56` |
| eyebrow "✦ 보상이 도착했어요" 펄스 | ✅ | `reward_unlock_modal.dart:31-33, 99-101` |
| 🎁/🎫 타이틀 | ✅ | `app_ko.arb:315` ICU plural |
| "당장 사용하시겠습니까?" CTA | ✅ | `reward_unlock_modal.dart:146` |
| ✅ 지금 사용 → 코드 카드 selectable | ✅ | `:45-55 _useNow → redeem`, `:226 SelectableText(r.code)` |
| 코드 보기 → redeem 없이 코드 | ✅ | `:62-65 _viewCode` skips redeem |
| 나중에 → 모달 닫힘 | ✅ | `:57-60 _later → maybePop()` |
| 챕터 5 → ticket > goods 정렬 | ✅ | `reward_controller.dart:44-46` |
| 이미 발급 → 모달 안 뜸 (idempotent) | ✅ | `:35-40 _modalOpen` + `newlyGranted.isEmpty` |
| Archive 진행도 "코드 보기" → 동일 모달 | 🔍 | `archive_screen.dart:3052` 버튼 존재, runtime wiring 미확정 |

---

### § 7 체크아웃 — 6 / 6 ✅

| 항목 | 결과 | 근거 |
|---|---|---|
| 할인 만료 다이얼로그 → 홈 | ✅ | `checkout_screen.dart:34-46 _expired` |
| 수량 ± 1~9 | ✅ | `:91 _qty.clamp(1, 9)` |
| 소계 / 루나 할인 / 총 결제 | ✅ | `:165 _SummaryRow` |
| disclaimer 💡 | ✅ | `:185`, `app_ko.arb:302` |
| 결제수단 시트 4종 (카카오/카드/네이버/계좌) | ✅ | `:653 enum _PayMethod`, sheet `:680-682` |
| 결제 완료 → QR → "마이 루나 시작하기" | ✅ | `:503 _PaymentDoneSheet`, mock QR `:566` |

---

### § 8 마이페이지 — 5 ✅ / 1 ❌

| 항목 | 결과 | 근거 |
|---|---|---|
| 언어 시스템/한국어/English 즉시 전환 | ✅ | `mypage_screen.dart:94-159` → `LocaleService.instance.setLocale` |
| 앱푸시 토글 | ✅ | `notification_settings_screen.dart:99-104` |
| 한산 알림 + 채널 (앱푸시/카카오/SMS) | ✅ | `:128-160`, FCM topic sync `:113` |
| 마케팅 OFF → 카카오·SMS 비활성 + 안내 | ✅ | `:142, 151`, 안내문 `:158-167` |
| 마지막 동의 시각 표시 | ✅ | `:186-194 notif_set_last_consent(_fmtConsentAt(...))` |
| **이용약관 / 개인정보 처리방침 링크** | ❌ | `mypage_screen.dart:266-271` SnackBar 만, 실제 화면/링크 없음 |

---

### § 9 영어 모드 — 3 ✅ / 2 ⚠️

| 항목 | 결과 | 근거 |
|---|---|---|
| 모든 화면 영어 (l10n 인프라) | ✅ | `app_localizations_en.dart` 482줄 |
| **Archive 시드 11권 영어** | ⚠️ | 실제 **10권만** seed (`archive_screen.dart` headlines `:623,651,672,700,721,746,768,790,812,838`) |
| 이벤트 이름 영어 12개 | ✅ | `:220-330` `_EventChapter` × 12 with `_LocPair` EN |
| 보상 모달 영어 | ✅ | `app_localizations_en.dart:266` 🎁/🎫, `:268` "Use it right now?" |
| iOS Info.plist 영어 (알려진 이슈) | ⚠️ | `ios/Runner/Info.plist:50` 한글만, `InfoPlist.strings` 부재 |

---

### § 10 백엔드 통합 — 9 / 9 ✅ (정적 검증만)

| 항목 | 결과 | 근거 |
|---|---|---|
| `/healthz` | ✅ | `backend/app.py:42-45` |
| `/healthz/full` 5 subsystems | ✅ | `:46-101` catalog/predictor/weather/narrative_ai/firebase |
| `/api/pricing/now` | ✅ | `:290` |
| `/api/route` | ✅ | `:219` |
| `/api/narrative` | ✅ | `:194` |
| `/api/rewards/check` | ✅ | `:369-396` |
| `/api/rewards/list?uid=guest` | ✅ | `:398-410` |
| `/api/rewards/redeem` | ✅ | `:412-430` |
| 백엔드 미설정 graceful fallback | ✅ | `route_service.dart:13,35-42` + `narrative_service.dart:12-17` + `luna_pricing_service.dart:16-25` |

> **주의:** 이 섹션은 100% 정적 검증입니다. 실측은 `backend/scripts/smoke_test.sh` 로 사용자 머신에서 수행해야 합니다.

---

### § 11 Edge / Fallback — 7 / 7 ✅

| 항목 | 결과 | 근거 |
|---|---|---|
| OSRM 타임아웃 5s+ → PathGraph → 직선 | ✅ | `osrm_router.dart:27` `Duration(seconds: 5)`, `:118-119` fallback |
| GPS 거부/없음 → 정문 fallback | ✅ | `map_screen.dart:44 _myPosition ?? _kGate` |
| GPS 정문 1.5km 밖 → "도착 전" | ✅ | `:194-217 _kRemoteThresholdM`, snackbar `:234` |
| Firebase Admin 없음 → 502 skipped | ✅ | `app.py:177-182 skipped=True, 502` |
| ANTHROPIC_API_KEY 없음 → 룰 기반 한/영 | ✅ | `app.py:90-93`, `narrative_service.dart:26-28` |
| API_BASE_URL 없음 → mock (no crash) | ✅ | `luna_pricing_service.dart:16-17` 등 |
| 빈 시즌 (책 0권) → 카드 + 0/5 + 점선 | ✅ | `archive_screen.dart:1154 _NextEventPlaceholder`, `:2927 _RewardProgressCard` |

---

### § 12 푸쉬 알림 — 4 ✅ / 2 ❌

| 항목 | 결과 | 근거 |
|---|---|---|
| FCM 토큰 발급 + 로그 | ✅ | `fcm_service.dart:51-58` |
| **`all_users` 토픽** | ❌ | `fcm_service.dart:23, 94` — `luna_pricing` 만 구독 |
| `luna_pricing` 토글 ON/OFF | ✅ | `:91-103`, `notification_settings_screen.dart:113` |
| `/api/run-pipeline` 한산 시 푸시 | ✅ | `app.py:167-183 run_pipeline(target)` |
| 포그라운드 SnackBar 배너 | ✅ | `main.dart:198-205 inboundMessages.listen` |
| **백그라운드 탭 → 라우팅** | ❌ | `fcm_service.dart:130-138 _onTap` log 만, "// TODO: 라우팅" 주석 |

---

### § 13 빌드 / 배포 — 1 ✅ / 1 ⚠️ / 3 🔍

| 항목 | 결과 | 근거 |
|---|---|---|
| `flutter analyze` 정적 검사 | 🔍 | 이 환경에서 분석기 실행 불가 |
| `flutter test` 디렉토리 | ✅ | 16개 테스트 파일 (`test/models`, `test/screens`, `test/services`, `test/widgets`) |
| `pytest backend/tests` | ⚠️ | 7개 `test_*.py` 가 `backend/tests/` 가 아닌 `backend/` 직속에 위치 (체크리스트 경로 불일치) |
| `flutter build web/apk/ios` | 🔍 | 실행 불가 |
| Cloud Run 배포 | 🔍 | 실행 불가 |

---

## 우선순위 액션 아이템 (출시 차단도 순)

| 우선순위 | 항목 | 작업 비용 |
|---|---|---|
| **P0** | § 8 약관·처리방침 페이지 (법적 의무) | 0.5d |
| **P0** | § 12 백그라운드 푸시 탭 라우팅 (UX 끊김) | 0.5d |
| **P1** | § 3 AI 스캔 FAB 연결 (widget 이미 존재) | 0.5h |
| **P1** | § 9 Archive seed 1권 추가 (10→11) | 1h |
| **P1** | § 12 `all_users` 토픽 구독 추가 | 1h |
| **P2** | § 4 stop 탭 동작 변경 (의도 확인 필요) | 0.5d |
| **P2** | § 2 TODAY EVENTS 3↔6 결정 | 1h |
| **P2** | § 3 일반 이스터에그 필터 추가 | 2h |
| **P3** | § 9 iOS Info.plist `InfoPlist.strings` (영어) | 2h |
| **P3** | § 13 backend tests `backend/tests/` 재배치 | 1h |

**총 추정:** P0~P1 약 2일, 전체 약 5일

---

## 다음 단계

1. **실측 검증** — 사용자 머신에서 백엔드 띄우고 `backend/scripts/smoke_test.sh` 실행 → § 10 객관 검증
2. **자동화 가능 픽스** — P1 항목 3개 (AI 스캔 wiring / Archive seed / all_users 토픽) 는 즉시 PR 가능
3. **제품 결정 필요** — § 4 stop 탭 의도, § 2 TODAY EVENTS 개수
4. **법무·기획 결정** — § 8 약관·처리방침 본문 확정
5. **수동 검증** — 🔍 마크 항목은 본인 머신에서 확인 후 체크박스 채우기

---

## 부록 — 점검 방식 상세

- **점검 도구:** 2개 일반 목적 audit agent 병렬 실행
- **검색 베이스:** `git show origin/feat/full-backend-stack:<path>` 로 source 추출 → `grep -nE` 패턴 매칭
- **결과 기록 4분류:**
  - ✅ — 코드 경로 확인됨
  - ❌ — 명시적 누락 / 깨짐
  - ⚠️ — 부분 구현 / 회귀 위험
  - 🔍 — 정적 검증 불가 (런타임/디바이스 필수)
- **점검 시간:** 약 12분 (병렬)
- **검사된 파일 수:** ~30개 (lib/screens, lib/services, lib/l10n, lib/widgets, backend/)
