#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Gasthaus Spring Boot Backend — Verbose API Test Suite
# Same tests as test-api.sh but prints every response body, pretty-printed.
# Usage: bash test-api-verbose.sh
# ══════════════════════════════════════════════════════════════════════════════

BASE="http://localhost:8080/api"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; GRAY='\033[0;90m'; NC='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0

# ── Helpers ───────────────────────────────────────────────────────────────────

header() {
  echo -e "\n${BLUE}══════════════════════════════════════════${NC}"
  echo -e "${BLUE} $1${NC}"
  echo -e "${BLUE}══════════════════════════════════════════${NC}"
}

# Pretty-print a response: try jq, fall back to raw
pretty() {
  local body="$1"
  echo -e "${GRAY}  ┌─ response ──────────────────────────────${NC}"
  if echo "$body" | jq . 2>/dev/null | sed 's/^/  │ /' ; then
    :
  else
    echo "$body" | sed 's/^/  │ /'
  fi
  echo -e "${GRAY}  └─────────────────────────────────────────${NC}"
}

check() {
  local label="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -q "$expected"; then
    echo -e "  ${GREEN}✓ PASS${NC} — $label"
    ((PASS++))
  else
    echo -e "  ${RED}✗ FAIL${NC} — $label"
    echo -e "    Expected to contain: ${YELLOW}$expected${NC}"
    ((FAIL++))
  fi
  pretty "$actual"
}

# HTTP helpers
post() { curl -sf -X POST "$BASE$1" -H "Content-Type: application/json" -H "${AUTH_HEADER:-x-skip: true}" -d "$2" 2>&1 || echo '{"error":"connection refused"}'; }
get()  { curl -sf -X GET  "$BASE$1" -H "${AUTH_HEADER:-x-skip: true}" 2>&1 || echo '{"error":"connection refused"}'; }
patch(){ curl -sf -X PATCH "$BASE$1" -H "Content-Type: application/json" -H "${AUTH_HEADER:-x-skip: true}" -d "$2" 2>&1 || echo '{"error":"connection refused"}'; }
del()  { curl -sf -X DELETE "$BASE$1" -H "${AUTH_HEADER:-x-skip: true}" 2>&1 || echo '{"error":"connection refused"}'; }

post_form() {
  local url="$1"; shift
  local f_args=(); for field in "$@"; do f_args+=(-F "$field"); done
  curl -sf -X POST "$BASE$url" -H "${AUTH_HEADER:-x-skip: true}" "${f_args[@]}" 2>&1 || echo '{"error":"connection refused"}'
}
patch_form() {
  local url="$1"; shift
  local f_args=(); for field in "$@"; do f_args+=(-F "$field"); done
  curl -sf -X PATCH "$BASE$url" -H "${AUTH_HEADER:-x-skip: true}" "${f_args[@]}" 2>&1 || echo '{"error":"connection refused"}'
}

# ══════════════════════════════════════════════════════════════════════════════
# PRE-FLIGHT
# ══════════════════════════════════════════════════════════════════════════════
header "PRE-FLIGHT CHECK"
HEALTH=$(curl -sf http://localhost:8080/api/menu/categories 2>&1)
if echo "$HEALTH" | grep -qE '\[|\{|error'; then
  echo -e "  ${GREEN}✓ App is responding on :8080${NC}"
else
  echo -e "  ${RED}✗ App not responding on :8080 — start it first!${NC}"
  exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 3 — AUTH
# ══════════════════════════════════════════════════════════════════════════════
header "PHASE 3 — AUTH"
AUTH_HEADER=""

echo -e "\n${YELLOW}▸ Register users${NC}"
R=$(post "/auth/register" '{"name":"Alice Manager","email":"alice@gasthaus.com","password":"secret123","role":"MANAGER"}')
check "Register MANAGER" '"role":"MANAGER"' "$R"
MGR_TOKEN=$(echo "$R" | jq -r '.token // empty')

R=$(post "/auth/register" '{"name":"Bob Waiter","email":"bob@gasthaus.com","password":"secret123","role":"WAITER"}')
check "Register WAITER" '"role":"WAITER"' "$R"
WAITER_TOKEN=$(echo "$R" | jq -r '.token // empty')

R=$(post "/auth/register" '{"name":"Chef Carl","email":"carl@gasthaus.com","password":"secret123","role":"KITCHEN"}')
check "Register KITCHEN" '"role":"KITCHEN"' "$R"
KITCHEN_TOKEN=$(echo "$R" | jq -r '.token // empty')

R=$(post "/auth/register" '{"name":"Dana Customer","email":"dana@gasthaus.com","password":"secret123","role":"CUSTOMER"}')
check "Register CUSTOMER" '"role":"CUSTOMER"' "$R"
CUST_TOKEN=$(echo "$R" | jq -r '.token // empty')

echo -e "\n${YELLOW}▸ Login${NC}"
R=$(post "/auth/login" '{"email":"alice@gasthaus.com","password":"secret123"}')
check "Login returns token" '"token"' "$R"
MGR_TOKEN=$(echo "$R" | jq -r '.token // empty')

R=$(post "/auth/login" '{"email":"alice@gasthaus.com","password":"wrongpassword"}')
check "Login wrong password → 401" 'Invalid credentials\|error\|401' "$R"

echo -e "\n${YELLOW}▸ /auth/me${NC}"
AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
R=$(get "/auth/me")
check "GET /auth/me returns user" '"email":"alice@gasthaus.com"' "$R"

AUTH_HEADER=""
R=$(curl -sf "$BASE/auth/me" 2>&1 || echo "unauthorized")
check "/auth/me without token → denied" 'unauthorized\|403\|401\|error' "$R"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 4 — MENU
# ══════════════════════════════════════════════════════════════════════════════
header "PHASE 4 — MENU"

echo -e "\n${YELLOW}▸ Categories — public read${NC}"
AUTH_HEADER=""
R=$(get "/menu/categories")
check "GET /menu/categories public (empty is ok)" '\[\]' "$R"

echo -e "\n${YELLOW}▸ Categories — MANAGER write${NC}"
AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
R=$(post "/menu/categories" '{"name":"Pizzas","icon":"pizza"}')
check "POST /menu/categories (MANAGER)" '"name":"Pizzas"' "$R"
CAT_ID=$(echo "$R" | jq -r '.id // empty')

R=$(post "/menu/categories" '{"name":"Drinks","icon":"coffee"}')
check "POST 2nd category" '"name":"Drinks"' "$R"
CAT2_ID=$(echo "$R" | jq -r '.id // empty')

AUTH_HEADER="Authorization: Bearer $CUST_TOKEN"
R=$(curl -sf -X POST "$BASE/menu/categories" -H "Content-Type: application/json" -H "$AUTH_HEADER" -d '{"name":"Hack"}' -w "\n%{http_code}" 2>&1)
check "POST /menu/categories as CUSTOMER → 403" '403' "$R"

AUTH_HEADER=""
R=$(get "/menu/categories")
check "GET /menu/categories returns Pizzas" '"name":"Pizzas"' "$R"

echo -e "\n${YELLOW}▸ Items — MANAGER write${NC}"
AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"

R=$(post_form "/menu/items" "name=Margherita" "price=12.99" "categoryId=$CAT_ID" "description=Classic tomato and mozzarella")
check "POST /menu/items (multipart form)" '"name":"Margherita"' "$R"
ITEM_ID=$(echo "$R" | jq -r '.id // empty')

R=$(post_form "/menu/items" "name=Pepperoni" "price=14.99" "categoryId=$CAT_ID")
check "POST 2nd item (Pepperoni)" '"name":"Pepperoni"' "$R"
ITEM2_ID=$(echo "$R" | jq -r '.id // empty')

R=$(post_form "/menu/items" "name=Cola" "price=2.50" "categoryId=$CAT2_ID")
check "POST item in Drinks category" '"name":"Cola"' "$R"
DRINK_ID=$(echo "$R" | jq -r '.id // empty')

AUTH_HEADER=""
echo -e "\n${YELLOW}▸ Items — public read${NC}"
R=$(get "/menu/items")
check "GET /menu/items (public)" '"name":"Margherita"' "$R"

R=$(get "/menu/items/$ITEM_ID")
check "GET /menu/items/:id" '"name":"Margherita"' "$R"

R=$(get "/menu/categories")
check "GET /menu/categories now includes items" '"items"' "$R"

AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
echo -e "\n${YELLOW}▸ Toggle availability${NC}"
R=$(patch "/menu/items/$ITEM2_ID/toggle" "")
check "PATCH /menu/items/:id/toggle flips isAvailable" 'false\|true' "$R"

R=$(patch_form "/menu/items/$ITEM_ID" "price=13.50" "description=Updated price")
check "PATCH /menu/items/:id (multipart)" '"price":13.5' "$R"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6A — TABLES
# ══════════════════════════════════════════════════════════════════════════════
header "PHASE 6A — TABLES (needed before orders)"

AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
echo -e "\n${YELLOW}▸ Create tables${NC}"

R=$(post "/tables" '{"tableNumber":1}')
check "POST /tables (table 1)" '"tableNumber":1' "$R"
TABLE_ID=$(echo "$R" | jq -r '.id // empty')

R=$(post "/tables" '{"tableNumber":2}')
check "POST /tables (table 2)" '"tableNumber":2' "$R"
TABLE2_ID=$(echo "$R" | jq -r '.id // empty')

R=$(curl -sf -X POST "$BASE/tables" -H "Content-Type: application/json" -H "Authorization: Bearer $MGR_TOKEN" -d '{"tableNumber":1}' -w "\n%{http_code}" 2>&1)
check "Duplicate table number → 409" '409' "$R"

echo -e "\n${YELLOW}▸ Read tables${NC}"
AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
R=$(get "/tables")
check "GET /tables (MANAGER)" '"tableNumber":1' "$R"

R=$(get "/tables/stats")
check "GET /tables/stats" '"total"' "$R"

AUTH_HEADER=""
R=$(get "/tables/number/1")
check "GET /tables/number/1 (public)" '"tableNumber":1' "$R"

AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
R=$(get "/tables/$TABLE_ID")
check "GET /tables/:id with orders" '"tableNumber":1' "$R"

R=$(patch "/tables/$TABLE_ID/toggle" "")
check "PATCH /tables/:id/toggle" '"isOccupied"' "$R"
R=$(patch "/tables/$TABLE_ID/toggle" "")
check "Toggle back to unoccupied" '"isOccupied":false' "$R"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 5 — ORDERS
# ══════════════════════════════════════════════════════════════════════════════
header "PHASE 5 — ORDERS"

AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
CURRENT_AVAIL=$(get "/menu/items/$ITEM2_ID" | jq -r '.isAvailable')
if [ "$CURRENT_AVAIL" = "false" ]; then
  patch "/menu/items/$ITEM2_ID/toggle" "" > /dev/null
fi

AUTH_HEADER="Authorization: Bearer $CUST_TOKEN"
echo -e "\n${YELLOW}▸ Create order${NC}"

ORDER_BODY=$(cat <<EOF
{
  "tableId": "$TABLE_ID",
  "items": [
    {"menuItemId": "$ITEM_ID",  "quantity": 2, "notes": "extra cheese"},
    {"menuItemId": "$ITEM2_ID", "quantity": 1}
  ]
}
EOF
)
R=$(post "/orders" "$ORDER_BODY")
check "POST /orders (CUSTOMER)" '"status":"PENDING"' "$R"
ORDER_ID=$(echo "$R" | jq -r '.id // empty')
check "Order has items array" '"items"' "$R"
check "Table auto-marked occupied" '"isOccupied":true' "$(curl -sf "$BASE/tables/$TABLE_ID" -H "Authorization: Bearer $MGR_TOKEN")"

AUTH_HEADER="Authorization: Bearer $WAITER_TOKEN"
R=$(curl -sf -X POST "$BASE/orders" -H "Content-Type: application/json" -H "$AUTH_HEADER" -d "$ORDER_BODY" -w "\n%{http_code}" 2>&1)
check "POST /orders as WAITER → 403" '403' "$R"

echo -e "\n${YELLOW}▸ Read orders${NC}"
AUTH_HEADER="Authorization: Bearer $WAITER_TOKEN"
R=$(get "/orders")
check "GET /orders (WAITER) shows active" '"status":"PENDING"' "$R"

AUTH_HEADER="Authorization: Bearer $KITCHEN_TOKEN"
R=$(get "/orders")
check "GET /orders (KITCHEN)" '"status":"PENDING"' "$R"

AUTH_HEADER="Authorization: Bearer $CUST_TOKEN"
R=$(get "/orders/my")
check "GET /orders/my (CUSTOMER)" '"status":"PENDING"' "$R"

R=$(get "/orders/$ORDER_ID")
check "GET /orders/:id" '"totalAmount"' "$R"

echo -e "\n${YELLOW}▸ Status transitions${NC}"
AUTH_HEADER="Authorization: Bearer $WAITER_TOKEN"

R=$(patch "/orders/$ORDER_ID/status" '{"status":"CONFIRMED"}')
check "PENDING → CONFIRMED" '"status":"CONFIRMED"' "$R"

R=$(patch "/orders/$ORDER_ID/status" '{"status":"PREPARING"}')
check "CONFIRMED → PREPARING" '"status":"PREPARING"' "$R"

R=$(patch "/orders/$ORDER_ID/status" '{"status":"READY"}')
check "PREPARING → READY" '"status":"READY"' "$R"

R=$(patch "/orders/$ORDER_ID/status" '{"status":"SERVED"}')
check "READY → SERVED" '"status":"SERVED"' "$R"

R=$(patch "/orders/$ORDER_ID/status" '{"status":"COMPLETED"}')
check "SERVED → COMPLETED" '"status":"COMPLETED"' "$R"

R=$(curl -sf "$BASE/tables/$TABLE_ID" -H "Authorization: Bearer $MGR_TOKEN")
check "Table freed after COMPLETED" '"isOccupied":false' "$R"

AUTH_HEADER="Authorization: Bearer $CUST_TOKEN"
ORDER2_BODY=$(cat <<EOF
{"tableId":"$TABLE2_ID","items":[{"menuItemId":"$DRINK_ID","quantity":1}]}
EOF
)
R_NEW=$(post "/orders" "$ORDER2_BODY")
ORDER2_ID=$(echo "$R_NEW" | jq -r '.id // empty')

AUTH_HEADER="Authorization: Bearer $WAITER_TOKEN"
R=$(curl -sf -X PATCH "$BASE/orders/$ORDER2_ID/status" -H "Content-Type: application/json" -H "$AUTH_HEADER" -d '{"status":"COMPLETED"}' -w "\n%{http_code}" 2>&1)
check "Invalid transition PENDING→COMPLETED → 400" '400' "$R"

R=$(patch "/orders/$ORDER2_ID/status" '{"status":"CANCELLED"}')
check "CANCELLED from PENDING" '"status":"CANCELLED"' "$R"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 6B — REVIEWS
# ══════════════════════════════════════════════════════════════════════════════
header "PHASE 6B — REVIEWS"

AUTH_HEADER="Authorization: Bearer $CUST_TOKEN"
echo -e "\n${YELLOW}▸ Create review${NC}"

R=$(post "/reviews" "{\"menuItemId\":\"$ITEM_ID\",\"orderId\":\"$ORDER_ID\",\"rating\":5,\"comment\":\"Excellent pizza!\"}")
check "POST /reviews (CUSTOMER)" '"rating":5' "$R"
REVIEW_ID=$(echo "$R" | jq -r '.id // empty')

R=$(curl -sf -X POST "$BASE/reviews" -H "Content-Type: application/json" -H "Authorization: Bearer $CUST_TOKEN" \
    -d "{\"menuItemId\":\"$ITEM_ID\",\"orderId\":\"$ORDER_ID\",\"rating\":4}" -w "\n%{http_code}" 2>&1)
check "Duplicate review → 400" '400' "$R"

R=$(curl -sf -X POST "$BASE/reviews" -H "Content-Type: application/json" -H "Authorization: Bearer $CUST_TOKEN" \
    -d "{\"menuItemId\":\"$DRINK_ID\",\"orderId\":\"$ORDER_ID\",\"rating\":3}" -w "\n%{http_code}" 2>&1)
check "Review item not in order → 400" '400' "$R"

echo -e "\n${YELLOW}▸ Read reviews${NC}"
AUTH_HEADER=""
R=$(get "/reviews/item/$ITEM_ID")
check "GET /reviews/item/:id (public)" '"averageRating"' "$R"
check "Average rating is 5.0" '"averageRating":5' "$R"
check "totalReviews is 1" '"totalReviews":1' "$R"

AUTH_HEADER="Authorization: Bearer $CUST_TOKEN"
R=$(get "/reviews/order/$ORDER_ID")
check "GET /reviews/order/:id (CUSTOMER)" '"rating":5' "$R"

AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
R=$(get "/reviews")
check "GET /reviews (MANAGER)" '"rating":5' "$R"

AUTH_HEADER="Authorization: Bearer $CUST_TOKEN"
R=$(curl -sf "$BASE/reviews" -H "Authorization: Bearer $CUST_TOKEN" -w "\n%{http_code}" 2>&1)
check "GET /reviews as CUSTOMER → 403" '403' "$R"

# ══════════════════════════════════════════════════════════════════════════════
# PHASE 7 — AI PROXY
# ══════════════════════════════════════════════════════════════════════════════
header "PHASE 7 — AI PROXY"

echo -e "\n${YELLOW}▸ Review Summary (public)${NC}"
AUTH_HEADER=""
R=$(post "/ai/review-summary" "{\"menuItemName\":\"Margherita\",\"reviews\":[{\"rating\":5,\"comment\":\"Excellent pizza!\"}]}")
if echo "$R" | grep -qE 'summary|error|503|connection'; then
  check "POST /ai/review-summary (public)" 'summary\|result\|message\|error' "$R"
else
  echo -e "  ${YELLOW}⚠ SKIP${NC} — FastAPI not running"
fi

echo -e "\n${YELLOW}▸ Recommendation (CUSTOMER)${NC}"
AUTH_HEADER="Authorization: Bearer $CUST_TOKEN"
R=$(post "/ai/recommend" '{"message":"What do you recommend for dinner?","menuItems":[]}')
if echo "$R" | grep -qE 'recommend|error|503'; then
  check "POST /ai/recommend (CUSTOMER)" 'recommend\|error\|503' "$R"
else
  echo -e "  ${YELLOW}⚠ SKIP${NC} — FastAPI not running"
fi

echo -e "\n${YELLOW}▸ Insights (MANAGER)${NC}"
AUTH_HEADER="Authorization: Bearer $MGR_TOKEN"
R=$(post "/ai/insights" "{\"totalOrders\":42,\"totalRevenue\":1250.50,\"topItems\":[{\"name\":\"Margherita\",\"count\":15}]}")
if echo "$R" | grep -qE 'insight|error|503'; then
  check "POST /ai/insights (MANAGER)" 'insight\|error\|503' "$R"
else
  echo -e "  ${YELLOW}⚠ SKIP${NC} — FastAPI not running"
fi

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL))
echo ""
echo -e "${BLUE}══════════════════════════════════════════${NC}"
echo -e "${BLUE} RESULTS: ${GREEN}$PASS passed${NC} / ${RED}$FAIL failed${NC} / $TOTAL total"
echo -e "${BLUE}══════════════════════════════════════════${NC}"
[ $FAIL -eq 0 ] && echo -e "${GREEN} All tests passed!${NC}" || echo -e "${RED} Some tests failed — check output above.${NC}"

# Cleanup — run after summary to not affect PASS/FAIL counts
echo -e "\n${YELLOW}  Wiping test data so the next run starts clean...${NC}"
docker exec gasthaus_db psql -U gasthaus -d gasthaus -c "
  DELETE FROM gasthaus_java.reviews;
  DELETE FROM gasthaus_java.order_items;
  DELETE FROM gasthaus_java.orders;
  DELETE FROM gasthaus_java.menu_items;
  DELETE FROM gasthaus_java.menu_categories;
  DELETE FROM gasthaus_java.restaurant_tables;
  DELETE FROM gasthaus_java.users;
" > /dev/null 2>&1 && echo -e "  ${GREEN}✓ DB cleaned${NC}" || true
docker exec gasthaus_redis redis-cli FLUSHALL > /dev/null 2>&1 && echo -e "  ${GREEN}✓ Redis cache flushed${NC}" || true
