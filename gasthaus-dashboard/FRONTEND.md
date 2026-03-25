# Gasthaus Dashboard — Frontend Implementation

Next.js 16 staff dashboard for the Gasthaus restaurant management system.
Connects to the **Spring Boot backend** on `localhost:8080`.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 (App Router) |
| Language | TypeScript |
| UI | React 19 + Tailwind CSS v4 |
| Data fetching | TanStack React Query v5 |
| Real-time | `@stomp/stompjs` + `sockjs-client` (STOMP over SockJS) |
| HTTP client | Axios |
| Forms | React Hook Form + Zod |
| Charts | Recharts v3 |
| Icons | Lucide React |

---

## Project Structure

```
gasthaus-dashboard/
├── app/
│   ├── layout.tsx                        # Root layout — Inter font, React Query provider
│   ├── globals.css                       # Tailwind v4 CSS config + global styles
│   ├── (auth)/
│   │   ├── layout.tsx                    # Auth group wrapper (minimal)
│   │   └── login/page.tsx                # Login page
│   ├── (dashboard)/
│   │   ├── layout.tsx                    # Dashboard layout — AuthGuard + Sidebar + Header
│   │   ├── dashboard/page.tsx            # Overview stats + live orders + tables map
│   │   ├── orders/page.tsx               # Kanban board
│   │   ├── menu/page.tsx                 # Menu management
│   │   ├── tables/page.tsx               # Floor plan
│   │   ├── reviews/page.tsx              # Review list + analytics
│   │   └── insights/page.tsx             # AI insights + charts
│   └── (fullscreen)/
│       ├── layout.tsx                    # Fullscreen layout — AuthGuard only, no chrome
│       └── kitchen/page.tsx              # Kitchen display system (KDS)
├── components/
│   ├── providers.tsx                     # React Query QueryClientProvider
│   ├── auth-guard.tsx                    # Client-side JWT auth check + redirect
│   ├── sidebar.tsx                       # Fixed 240px dark sidebar with nav
│   ├── header.tsx                        # Fixed 56px top header
│   └── ui/button.tsx                     # shadcn button stub
├── lib/
│   ├── api.ts                            # Axios instance → localhost:8080/api
│   ├── auth.ts                           # localStorage auth helpers
│   ├── socket.ts                         # STOMP client factory + topic constants
│   └── utils.ts                          # cn() utility (clsx + tailwind-merge)
└── types/
    └── index.ts                          # TypeScript interfaces + enums
```

---

## Route Groups

Next.js route groups (parentheses) affect layout inheritance without changing URL paths.

| Group | URL paths | Layout applied |
|-------|-----------|----------------|
| `(auth)` | `/login` | Minimal wrapper |
| `(dashboard)` | `/dashboard`, `/orders`, `/menu`, `/tables`, `/reviews`, `/insights` | AuthGuard + Sidebar + Header |
| `(fullscreen)` | `/kitchen` | AuthGuard only — dark full-screen, no sidebar/header |

---

## Infrastructure

### `lib/api.ts` — Axios client
- Base URL: `http://localhost:8080/api` (Spring Boot, override with `NEXT_PUBLIC_API_URL`)
- Request interceptor: auto-injects `Authorization: Bearer <token>` from localStorage
- Response interceptor: on 401 with existing token → clears auth and redirects to `/login`

### `lib/auth.ts` — Auth helpers
localStorage keys: `gasthaus_token` (JWT string), `gasthaus_user` (JSON-serialised user object)

| Function | Purpose |
|----------|---------|
| `getToken()` | Returns JWT string or null |
| `getUser()` | Returns parsed User object or null |
| `setAuth(token, user)` | Stores both in localStorage |
| `clearAuth()` | Removes both keys |
| `isAuthenticated()` | Returns `getToken() !== null` |

### `lib/socket.ts` — STOMP WebSocket
Spring Boot uses **STOMP over SockJS** — incompatible with `socket.io-client`.

```ts
createStompClient()   // returns a new @stomp/stompjs Client
                      // connects to http://localhost:8080/api/ws via SockJS
                      // reconnectDelay: 5000ms

TOPICS = {
  ORDER_NEW:    '/topic/order.new',
  ORDER_STATUS: '/topic/order.status',
  ORDER_READY:  '/topic/order.ready',
}
```

Usage pattern in every real-time page:
```ts
useEffect(() => {
  const client = createStompClient()
  client.onConnect = () => {
    client.subscribe(TOPICS.ORDER_NEW,    () => queryClient.invalidateQueries(...))
    client.subscribe(TOPICS.ORDER_STATUS, () => queryClient.invalidateQueries(...))
  }
  client.activate()
  return () => { client.deactivate() }
}, [queryClient])
```

### `components/providers.tsx` — React Query
Wraps the root layout. Single `QueryClient` per session with:
- `staleTime: 30_000` (30 seconds before background refetch)
- `retry: 1`

### `components/auth-guard.tsx` — Route protection
Client-side guard (JWT in localStorage is inaccessible to Next.js middleware).
- Runs `isAuthenticated()` on mount via `useEffect`
- Redirects to `/login` if no token
- Renders `null` on server/before hydration if unauthenticated (prevents flash)

### `types/index.ts` — TypeScript types

```ts
enum Role          { CUSTOMER, WAITER, KITCHEN, MANAGER }
enum OrderStatus   { PENDING, CONFIRMED, PREPARING, READY, SERVED, COMPLETED, CANCELLED }

interface User             { id, name, email, role }
interface MenuCategory     { id, name, icon?, items? }
interface MenuItem         { id, name, description?, price, imageUrl?, isAvailable, categoryId, category? }
interface OrderItem        { id, quantity, unitPrice, notes?, menuItem }
interface RestaurantTable  { id, tableNumber, qrCode?, isOccupied, orders? }
interface Order            { id, status, totalAmount, createdAt, customerId, tableId?, items, customer?, table? }
interface Review           { id, rating, comment?, createdAt, customer?, menuItem? }
```

---

## Design System

| Token | Value |
|-------|-------|
| Sidebar background | `#1C1C1E` |
| Active nav item | `bg-[#2C2C2C]` + `border-l-2 border-[#D97706]` |
| Amber accent | `#D97706` (hover/active: `#B45309`) |
| Content background | `#F9F9F7` |
| Card background | `#FFFFFF` |
| Border | `1px solid #E5E7EB` |
| Font | Inter (via `next/font/google`) |
| Max border-radius | `8px` |
| No shadows, no gradients | — |

---

## Shared Components

### `components/sidebar.tsx`
- Fixed, 240px wide, `bg-[#1C1C1E]`, `z-50`
- Brand: UtensilsCrossed icon + "GASTHAUS" text
- 7 nav items using `usePathname()` for active detection
- Active state: `bg-[#2C2C2C]` + amber left border + amber icon
- Bottom: user initials avatar (from localStorage) + role

### `components/header.tsx`
- Fixed, 56px tall, white, `left-[240px]`
- Dynamic page title derived from `usePathname()`
- Formatted date, notification bell, user avatar

---

## Pages

### Login `/login`
**File:** `app/(auth)/login/page.tsx`

Split-screen layout: dark photo left (55%), white form right (45%).

- Form: react-hook-form + zod schema (email + password ≥6 chars)
- Password toggle (show/hide)
- Server error banner on failed login
- On success: calls `POST /auth/login`, stores JWT + user via `setAuth()`, role-based redirect:
  - `KITCHEN` → `/kitchen`
  - All others → `/dashboard`
- Redirects to `/dashboard` if already authenticated

---

### Dashboard `/dashboard`
**File:** `app/(dashboard)/dashboard/page.tsx`

**Data:** `GET /orders`, `GET /tables`

**4 stat cards** (top row, 4-column grid):
| Card | Source |
|------|--------|
| Total Orders Today | Filter orders where `createdAt` is today |
| Revenue Today | Sum `totalAmount` for today's orders |
| Active Tables | Count `isOccupied = true` / total |
| Pending Orders | Count `status === PENDING \| CONFIRMED` |

**Live Orders panel** (60%): last 6 orders sorted newest-first.
Each row: table badge (`T{n}`), customer name, item count + time, amount, colour-coded status pill.

Status pill colours:
| Status | Style |
|--------|-------|
| PENDING | `bg-zinc-200 text-zinc-600` |
| CONFIRMED | `bg-blue-100 text-blue-700` |
| PREPARING | `bg-amber-100 text-amber-700` |
| READY | `bg-emerald-100 text-emerald-700` |
| SERVED | `bg-zinc-200 text-zinc-600` |
| COMPLETED | `bg-zinc-100 text-zinc-400` |
| CANCELLED | `bg-red-100 text-red-600` |

**Tables mini-map** (40%): 4-column grid of table squares.
- Occupied: `bg-amber-50 border-amber-200 text-amber-700`
- Free: `bg-zinc-50 border-[#E5E7EB] text-zinc-400`
- Occupancy % progress bar at bottom

**Real-time:** STOMP subscriptions to `ORDER_NEW` + `ORDER_STATUS` → `queryClient.invalidateQueries`

---

### Orders `/orders`
**File:** `app/(dashboard)/orders/page.tsx`

Full-height Kanban board (`h-[calc(100vh-56px)]`). Horizontal scroll, 5 columns × 280px.

**Columns:**
| Column | Badge colour | Action button | Next status | Card accent |
|--------|-------------|---------------|-------------|-------------|
| PENDING | Amber | Confirm | CONFIRMED | None |
| CONFIRMED | Blue | Prep | PREPARING | None |
| PREPARING | Purple | Ready | READY | Purple left border (3px) |
| READY | Green | Serve | SERVED | Green left border (3px) |
| SERVED | Gray | — (Done) | — | Dimmed opacity |

**Order card**: table label, time-ago, customer name, first 2 items summary (`+ …` if more), amount, action button.

Action buttons call `PATCH /orders/:id/status` via `useMutation`. On success, invalidates `['orders']` cache.

**Filter bar**: search by customer name or table number (client-side), Today/This Week period toggle, Refresh button (spins while fetching).

**Real-time:** STOMP `ORDER_NEW` + `ORDER_STATUS` → cache invalidation.

---

### Kitchen `/kitchen`
**File:** `app/(fullscreen)/kitchen/page.tsx`

Standalone full-screen dark display. **No sidebar or header.**
Route group `(fullscreen)` applies only `AuthGuard` — no layout chrome.

**Header bar:** branding, live clock + date (ticks every second via `setInterval`), active/ready counts.

**Card grid:** `grid-cols-4 auto-rows-fr` fills viewport height.

Card states derived from order status + elapsed time:
| State | Border | Timer colour | Button |
|-------|--------|-------------|--------|
| `new` (CONFIRMED) | Amber | Green | "Start Preparing" → PREPARING |
| `preparing` (<15 min) | Blue | Amber | "Mark Ready" → READY |
| `overdue` (≥15 min PREPARING) | Red + pulse | Red + pulse | "Mark Ready" → READY |
| `ready` (READY) | Green | Red | "Collected ✓" (disabled) |

Each card: large table number (44px), elapsed timer, order ID, up to 3 items, "+ N more" overflow label.

**Footer legend:** New Order / In Progress / Ready to Collect / Overdue.

**Real-time:** STOMP `ORDER_NEW` + `ORDER_STATUS` → cache invalidation. Polling fallback every 30s.

---

### Menu `/menu`
**File:** `app/(dashboard)/menu/page.tsx`

Three-panel layout inside the dashboard content area:

```
[ Category sidebar 200px ] [ Item grid flex-1 ] [ Edit panel 360px (conditional) ]
```

**Data:** `GET /menu/categories` (returns categories with nested items)

**Category sidebar:**
- "All Items" button + per-category buttons with item counts
- Active state: amber tint
- Hover → reveals delete (×) per category → `DELETE /menu/categories/:id`
- Inline "Add Category" form: Enter to confirm → `POST /menu/categories`, Escape to cancel

**Item grid (3-column):**
- `GET /menu/categories` flattened to all items, filtered by selected category + search
- Card: image (140px, grayscale if unavailable), name, price, category label
- Unavailable cards: `opacity-60` + grayscale image
- Availability toggle (inline, `stopPropagation`): `PATCH /menu/items/:id/toggle`
- Click card → opens edit panel with amber ring on selected card
- "Add Item" button → opens panel in create mode

**Edit panel:**
- Image upload area: `<input type="file" accept="image/*">`, blob URL preview, cleaned up on unmount
- Underline-style form fields (border-bottom only): name, description, price, category select
- Availability toggle
- Save → `PATCH /menu/items/:id` or `POST /menu/items` (multipart/form-data with `image` field)
- Discard → closes panel
- "Remove from Menu" (create mode hidden) → `DELETE /menu/items/:id` with confirm dialog

---

### Tables `/tables`
**File:** `app/(dashboard)/tables/page.tsx`

Two-panel layout:

```
[ Floor plan + stats  flex-1 ] [ Detail panel 320px ]
```

**Data:** `GET /tables`, `GET /orders` (joined client-side)

**Stats bar (4 cards):** Total Tables, Occupied (red), Available (green), Avg Duration (static `—`).

**Floor plan:** `bg-[#FAFAFA]` with dot-grid CSS background (`radial-gradient`), sorted 4-column grid.

Table tile variants:
- **Occupied** (with active order): white card, table number, customer name, order amount, red bottom bar
- **Available**: dashed border, green dot, gray number
- **Selected**: amber `ring-2` on either variant

Active order is derived client-side: `orders` are filtered to `PENDING | CONFIRMED | PREPARING | READY` statuses, mapped by `tableId` (most recent wins).

**Add Table:** button → inline form above floor plan → `POST /tables { tableNumber }`. Enter or button to confirm, Escape to cancel.

**Detail panel (320px):**
- Large T-number, Occupied/Available badge
- If occupied with order: customer, seated duration (live-computed), current amount, order status pill, "seated since" time
- "Mark as Available / Occupied" → `PATCH /tables/:id/toggle`
- "Delete Table" → `DELETE /tables/:id` with confirm dialog
- No selection: placeholder icon + prompt text

---

### Reviews `/reviews`
**File:** `app/(dashboard)/reviews/page.tsx`

**Data:** `GET /reviews`

65/35 layout: review list left, stats sidebar right.

**Filter bar:**
- Menu item dropdown (populated dynamically from review data)
- Star rating dropdown (1–5)
- Date range (Last 7 Days / Last 30 Days / All Time)
- Sort toggle (Latest First / Oldest First)
- All filtering done client-side

**Review cards:**
- Avatar: initials with deterministic background colour (hash of customer name → 6 colour palette)
- Header: customer name, menu item badge, star row (lucide `Star` icon, filled/empty), time ago
- Low-rated cards (≤2★): `border-l-[3px] border-l-red-500` — attention indicator
- Footer: short order ID

**Stats sidebar (300px):**
- **Rating Overview**: large avg score (1 decimal), star row, 5→1 distribution bars (width = percentage of total)
- **Item Performance**: per-item avg rating from all reviews, top 5, sorted descending
- **Sentiment**: Positive (≥4★) / Neutral (3★) / Negative (≤2★) pill counts
- **Quick Insight**: shown only when negative reviews exist — surfaces % negative + suggestion text

All stats computed from `reviews` array — no additional endpoints.

---

### Insights `/insights`
**File:** `app/(dashboard)/insights/page.tsx`

**Data:** `GET /orders`, `GET /reviews`, `POST /ai/insights` (on demand)

**Period toggle** (Today / This Week / This Month): filters all computed metrics.

**AI Insights card** (amber left border):
- Shows placeholder until "Generate Insights" clicked
- Calls `POST /ai/insights` with `{ period, totalOrders, totalRevenue, avgOrderValue, avgRating }`
- Accepts response as `{ insight }`, `{ message }`, `{ response }`, or raw string
- Error state shown inline
- Three cosmetic action buttons (View Full Report, Apply Suggestions, Export PDF)

**Charts row (3 columns, 220px tall):**

| Chart | Library | Data source |
|-------|---------|-------------|
| Hourly Orders | recharts `BarChart` | Today's orders grouped by hour (9AM–9PM) |
| Revenue This Week | recharts `AreaChart` + gradient | Last 7 days grouped by day of week |
| Top Items | CSS horizontal bars | Period-filtered order items, counted by item name |

**Bottom row:**
- **Key Metrics** (2×2): Avg Order Value, Total Revenue, Customer Satisfaction (reviews avg / 5), Kitchen Efficiency (100% − cancelled%)
- **Recommended Actions** (3 items): first item is data-driven (top item by order count), remaining two are static suggestions

---

## API Reference

All requests go to `http://localhost:8080/api`. JWT Bearer token auto-injected by Axios interceptor.

| Method | Endpoint | Used by |
|--------|----------|---------|
| POST | `/auth/login` | Login page |
| GET | `/orders` | Dashboard, Orders, Tables, Insights |
| PATCH | `/orders/:id/status` | Orders, Kitchen |
| GET | `/menu/categories` | Menu |
| POST | `/menu/items` | Menu (create, multipart) |
| PATCH | `/menu/items/:id` | Menu (edit, multipart) |
| DELETE | `/menu/items/:id` | Menu |
| PATCH | `/menu/items/:id/toggle` | Menu (inline toggle) |
| POST | `/menu/categories` | Menu |
| DELETE | `/menu/categories/:id` | Menu |
| GET | `/tables` | Dashboard, Tables |
| POST | `/tables` | Tables |
| PATCH | `/tables/:id/toggle` | Tables |
| DELETE | `/tables/:id` | Tables |
| GET | `/reviews` | Reviews, Insights |
| POST | `/ai/insights` | Insights |

---

## WebSocket Events (STOMP)

Connection: `http://localhost:8080/api/ws` via SockJS transport.

| Topic | Published when | Subscribed by |
|-------|---------------|--------------|
| `/topic/order.new` | New order placed | Dashboard, Orders, Kitchen |
| `/topic/order.status` | Order status changed | Dashboard, Orders, Kitchen |
| `/topic/order.ready` | Order marked READY | Kitchen (available, not subscribed explicitly) |

On every event, the subscriber calls `queryClient.invalidateQueries({ queryKey: ['orders'] })` which triggers a React Query background refetch. Tables cache is also invalidated on `order.status` (occupancy may change).

---

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `NEXT_PUBLIC_API_URL` | `http://localhost:8080/api` | Backend base URL |
| `NEXT_PUBLIC_WS_URL` | `http://localhost:8080/api/ws` | STOMP WebSocket endpoint |

Set in `.env.local` to override defaults.

---

## Running Locally

```bash
# Install dependencies
npm install

# Start development server (port 3000)
npm run dev

# Type check
npx tsc --noEmit

# Build for production
npm run build
```

Requires the Spring Boot backend running on port 8080.
