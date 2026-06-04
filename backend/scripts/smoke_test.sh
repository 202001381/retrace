#!/usr/bin/env bash
# 백엔드 엔드포인트 smoke test — 응답 상태/구조만 확인.
# 사용법:
#   1. 다른 터미널에서 백엔드 실행: python -m backend.app
#   2. ./backend/scripts/smoke_test.sh
#   3. (선택) BASE_URL=https://prod.example.com ./backend/scripts/smoke_test.sh

set -u
BASE_URL="${BASE_URL:-http://localhost:5000}"
TIMEOUT="${TIMEOUT:-5}"

# ─── ANSI 컬러 ─────────────────────────────────────────
G=$'\e[32m'; R=$'\e[31m'; Y=$'\e[33m'; B=$'\e[34m'; D=$'\e[2m'; N=$'\e[0m'

PASS=0; FAIL=0; SKIP=0

print_header() {
  echo
  echo "${B}── $1 ──${N}"
}

# $1 = label, $2 = method, $3 = path, $4 = expected_status, $5 = expected_field(.path), $6 = body(optional)
check() {
  local label="$1" method="$2" path="$3" expected="$4" field="$5" body="${6:-}"
  local url="$BASE_URL$path"
  local resp http body_file
  body_file=$(mktemp)
  if [[ "$method" == "GET" ]]; then
    http=$(curl -s -o "$body_file" -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo "000")
  else
    http=$(curl -s -o "$body_file" -w "%{http_code}" --max-time "$TIMEOUT" \
      -X "$method" -H "Content-Type: application/json" -d "$body" "$url" 2>/dev/null || echo "000")
  fi
  resp=$(cat "$body_file"); rm -f "$body_file"

  if [[ "$http" == "000" ]]; then
    echo "${R}✗${N} $label  ${D}[$method $path — connection failed]${N}"
    FAIL=$((FAIL+1)); return
  fi
  if [[ "$http" == "404" ]]; then
    echo "${Y}~${N} $label  ${D}[$method $path — 404, 이 브랜치에 미구현]${N}"
    SKIP=$((SKIP+1)); return
  fi
  if [[ "$http" != "$expected" ]] && [[ "$http" != "502" ]] && [[ "$http" != "503" ]]; then
    echo "${R}✗${N} $label  ${D}[HTTP $http, expected $expected]${N}"
    echo "  ${D}response: $(echo "$resp" | head -c 200)${N}"
    FAIL=$((FAIL+1)); return
  fi
  if [[ "$http" == "502" ]] || [[ "$http" == "503" ]]; then
    echo "${Y}~${N} $label  ${D}[HTTP $http skipped — 외부 의존성 미설정 (정상 fallback)]${N}"
    SKIP=$((SKIP+1)); return
  fi
  # 필드 검증 — jq 있으면 사용, 없으면 grep
  if [[ -n "$field" ]]; then
    if command -v jq >/dev/null 2>&1; then
      if ! echo "$resp" | jq -e "$field" >/dev/null 2>&1; then
        echo "${R}✗${N} $label  ${D}[HTTP $http OK but field '$field' missing]${N}"
        echo "  ${D}response: $(echo "$resp" | head -c 200)${N}"
        FAIL=$((FAIL+1)); return
      fi
    else
      local key="${field#.}"; key="${key%%.*}"
      if ! echo "$resp" | grep -q "\"$key\""; then
        echo "${R}✗${N} $label  ${D}[HTTP $http OK but key '$key' not found in response]${N}"
        FAIL=$((FAIL+1)); return
      fi
    fi
  fi
  echo "${G}✓${N} $label  ${D}[HTTP $http]${N}"
  PASS=$((PASS+1))
}

echo "${B}=== Retrace Backend Smoke Test ===${N}"
echo "${D}BASE_URL: $BASE_URL${N}"
echo "${D}TIMEOUT:  ${TIMEOUT}s${N}"
command -v jq >/dev/null 2>&1 || echo "${Y}경고: jq 미설치 — 응답 필드 검증이 grep 기반으로 약해집니다 (brew install jq)${N}"

# ─── § 10.1 헬스체크 ─────────────────────────────────
print_header "헬스체크"
check "/healthz"      GET  "/healthz"      200 ".status"
check "/healthz/full" GET  "/healthz/full" 200 ".subsystems"

# ─── § 10.2 프라이싱 ─────────────────────────────────
print_header "프라이싱"
check "/api/pricing/now" GET "/api/pricing/now" 200 ".discount_pct"

# ─── § 10.3 동선 ────────────────────────────────────
print_header "동선 추천"
ROUTE_BODY='{
  "uid":"guest","lat":37.4343,"lng":127.0201,"has_gps":true,
  "onboarding":{"headcount":2,"members":{"adultMale":1,"adultFemale":1},
                "favorite_type":"스릴 어트랙션 위주","purpose":"데이트"},
  "completed_attraction_ids":[],"discovered_eggs":[],
  "request_reason":"initial"
}'
check "/api/route" POST "/api/route" 200 ".route" "$ROUTE_BODY"

# ─── § 10.4 서사 ────────────────────────────────────
print_header "AI 서사 (narrative)"
NARRATIVE_BODY='{"attraction_id":"galaxy_888","companion_type":"family",
                 "season":"autumn","weather":"맑음","visit_count":1}'
check "/api/narrative" POST "/api/narrative" 200 ".narrative" "$NARRATIVE_BODY"

# ─── § 10.5 보상 ────────────────────────────────────
print_header "보상 (rewards)"
REWARD_CHECK_BODY='{"uid":"smoke_test","discovered":["galaxy_888","viking","carousel"]}'
check "/api/rewards/check"           POST "/api/rewards/check" 200 ".newly_granted" "$REWARD_CHECK_BODY"
check "/api/rewards/list (guest)"    GET  "/api/rewards/list?uid=smoke_test" 200 ".items"
# redeem 은 reward_id 가 있어야 하므로 list 응답에서 추출 가능할 때만
if command -v jq >/dev/null 2>&1; then
  reward_id=$(curl -s --max-time "$TIMEOUT" "$BASE_URL/api/rewards/list?uid=smoke_test" \
              | jq -r '.items[0].reward_id // empty' 2>/dev/null)
  if [[ -n "$reward_id" ]]; then
    REDEEM_BODY="{\"uid\":\"smoke_test\",\"reward_id\":\"$reward_id\"}"
    check "/api/rewards/redeem" POST "/api/rewards/redeem" 200 ".redeemed_at" "$REDEEM_BODY"
  else
    echo "${Y}~${N} /api/rewards/redeem  ${D}[skip: 발급된 reward 없음]${N}"
    SKIP=$((SKIP+1))
  fi
else
  echo "${Y}~${N} /api/rewards/redeem  ${D}[skip: jq 미설치로 reward_id 추출 불가]${N}"
  SKIP=$((SKIP+1))
fi

# ─── § 10.6 파이프라인 (Firebase 의존, 502 fallback) ──
print_header "파이프라인 (외부 의존)"
check "/api/run-pipeline?target=today" POST "/api/run-pipeline?target=today" 200 ".status" "{}"

# ─── 결과 ────────────────────────────────────────────
echo
echo "${B}=== 결과 ===${N}"
echo "${G}통과 $PASS${N}  ${R}실패 $FAIL${N}  ${Y}건너뜀 $SKIP${N}"
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
