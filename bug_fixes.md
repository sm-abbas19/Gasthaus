# Bug Fixes Log

---

## BF-001 — Menu screen crash when searching returns empty results

**File:** `gasthaus_app/lib/features/menu/menu_screen.dart`  
**Date:** 2026-04-02

### What
The Flutter app crashed (lost device connection) whenever the search bar on the menu screen produced no results, or when switching between having results and having none.

### Why
`Consumer<MenuProvider>` was placed directly in `CustomScrollView.slivers`. Consumer is a `ComponentElement` with no `RenderObject` of its own — Flutter looks through it to its child's `RenderSliver`. This works, but only if the child's sliver type is **stable**.

The bug: the Consumer's builder returned different outer sliver types depending on state:
- Loading / data present → `SliverPadding(sliver: SliverGrid(...))`
- Empty / error → `SliverToBoxAdapter(...)`

When search caused a transition between these states, the viewport's child list received a different `RenderSliver` type at the same slot. The viewport's layout pass could not reconcile this and crashed the app.

### Fix
Made the Consumer's builder **always** return `SliverPadding` as the outer widget. Only the *inner* sliver varies (`SliverGrid` for loading/data, `SliverToBoxAdapter` for empty/error). The outer type is now stable across all state transitions, so the viewport's child list stays consistent.

---

## BF-002 — Menu STOMP subscription silently dropped before WebSocket connects

**File:** `gasthaus_app/lib/core/services/socket_service.dart`  
**Date:** 2026-04-02

### What
Menu updates from the dashboard took 30–60 seconds to appear in the Flutter app instead of being instant. The STOMP WebSocket push was not being received.

### Why
`MenuProvider`'s constructor calls `subscribeToMenu()` immediately. At that point the WebSocket handshake hasn't completed yet (`_isConnected = false`, `_client` may be null). `_client?.subscribe(...)` returned null — the subscription was silently dropped. The only update mechanism that worked was the 60-second polling fallback, explaining the exact 30–60 second delay.

### Fix
Added a `_callbacks` map (persistent intent) alongside the existing `_subscriptions` map (active handles). Every subscribe call now stores its callback in `_callbacks`. `_onConnect` iterates `_callbacks` and activates all of them — handling both the initial connection race and automatic re-subscription after reconnects.

---

## BF-006 — STOMP WebSocket never connected — menu/order pushes never received

**File:** `gasthaus_app/lib/core/services/socket_service.dart`  
**Date:** 2026-04-02

### What
Real-time updates (menu changes, order status) never arrived via WebSocket. The app only updated on manual pull-to-refresh or the 60s polling fallback.

### Why
`_wsUrl` had two mistakes:

1. **Wrong scheme — `ws://` instead of `http://`**: The backend uses SockJS (`.withSockJS()` in `WebSocketConfig`). SockJS starts with an HTTP handshake to negotiate the transport. Passing a `ws://` URL bypasses SockJS entirely — the connection silently fails to establish, `_onConnect` never fires, and no subscriptions are ever activated.

2. **Missing `/api` prefix**: Spring Boot is configured with `server.servlet.context-path=/api` in `application.properties`. Every endpoint — including WebSocket — lives under `/api`. The registered endpoint `/ws` is therefore reachable at `/api/ws`, not `/ws`.

The correct URL is `http://10.0.2.2:8080/api/ws`.

### Fix
Changed `_wsUrl` from `ws://10.0.2.2:8080/ws` to `http://10.0.2.2:8080/api/ws`.

**Follow-up (BF-006b — definitive fix):** Reading the `stomp_dart_client` v3 source revealed the actual architecture: `StompClient` has its **own** built-in reconnect timer triggered by `onWebSocketDone`. Our manual `_scheduleReconnect()` called `activate()` at the same time, causing two concurrent `_connect()` calls that each created a new `StompHandler` — the second overwrote the first, producing a handler in an inconsistent state where `subscribe()` would throw `StompBadStateException`. Also, `subscribe()` throws when `_handler` is null (before connection), which `_client?.` null-safety does not protect against. Final fix: removed all manual reconnect logic; `connect()` creates the client once and never calls `activate()` again; the library's `reconnectDelay: 3s` handles all reconnects; `_onConnect` clears and re-registers subscriptions on every (re)connect; `onWebSocketDone` resets state without interfering with the library's reconnect timer.

---

## BF-007 — STOMP connection drops every ~10s causing pushes to only work once

**Files:** `gasthaus_app/lib/core/services/socket_service.dart`, `gasthaus-backend-java/.../config/WebSocketConfig.java`  
**Date:** 2026-04-02

### What
STOMP pushes only worked for the first change (with a 4-5s delay). Subsequent changes took 30-45s (polling fallback).

### Why
The Flutter client had `heartbeatIncoming: Duration(seconds: 10)` — telling the server "send me a heartbeat every 10s." Spring Boot's simple broker requires a `TaskScheduler` to send heartbeats; without one, `setHeartbeatValue()` is silently ignored and no heartbeats are ever sent. The STOMP client, receiving no heartbeats, declared the connection dead after 10s and triggered a reconnect (3s delay). Only the brief window between reconnect and next timeout (~10s) could receive a push — explaining the "first change only" pattern and the 4-5s delay (3s reconnect + connection overhead).

### Fix
- **Flutter**: Set `heartbeatIncoming: Duration.zero` — client no longer expects incoming heartbeats from the server, so the connection is never dropped due to missing heartbeats.
- **Spring Boot**: Added a `ThreadPoolTaskScheduler` bean and wired it to `enableSimpleBroker().setTaskScheduler()` with `setHeartbeatValue([10000, 10000])` so the broker can now properly send heartbeats. Also added `/queue` to the broker prefix for user-specific queues.

---

## BF-005 — Unavailable items always shown as "Available" in Flutter app

**File:** `gasthaus_app/lib/core/models/menu_item.dart`  
**Date:** 2026-04-02

### What
Items marked unavailable in the manager dashboard still showed the green "Available" badge in the Flutter app.

### Why
The Java entity field is `Boolean isAvailable`. Lombok's `@Getter` generates `getIsAvailable()`. Jackson serializes this as the JSON key `"isAvailable"` (strips "get", keeps "is" prefix). Flutter's `MenuItem.fromJson` was reading `json['available']`, which is always `null` in the response, so it defaulted to `true`.

### Fix
Changed the key lookup to `json['isAvailable']` with `json['available']` as a fallback for forward compatibility.

---

## BF-004 — Unavailable menu items disappeared from Flutter app instead of showing "Out of Stock"

**Files:** `gasthaus_app/lib/features/menu/menu_provider.dart`, `gasthaus_app/lib/features/menu/widgets/menu_item_card.dart`  
**Date:** 2026-04-02

### What
When a manager toggled an item to unavailable in the dashboard, it disappeared entirely from the customer Flutter app instead of staying visible as "Out of Stock".

### Why
The Flutter app called `GET /menu/categories` without parameters. The backend's default handler calls `findAllWithAvailableItemsOrderedByName()` — a JPQL query with `WHERE i.isAvailable = true`, filtering out unavailable items entirely. The backend already had a `?all=true` variant that returns all items regardless of availability, but the Flutter app never used it.

### Fix
- **Backend**: No code change needed — `GET /menu/categories?all=true` already existed via `findAllWithAllItemsOrderedByName()`.
- **Flutter (`menu_provider.dart`)**: Added `queryParameters: {'all': 'true'}` to both `loadMenu()` and `_silentReload()` calls.
- **Flutter (`menu_item_card.dart`)**: Changed the `_AvailabilityBadge` for unavailable items from a grey badge to a red badge (`AppColors.errorLight` background, `AppColors.error` text, "Out of Stock" label).

---

## BF-008 — STOMP menu push only worked once; order status push never worked

**Files:** `gasthaus_app/lib/core/services/socket_service.dart`, `gasthaus-backend-java/.../config/WebSocketConfig.java`, `gasthaus-backend-java/.../websocket/OrdersGateway.java`, `gasthaus-backend-java/.../security/SecurityConfig.java`  
**Date:** 2026-04-02

### What
Two separate STOMP bugs discovered together:

1. **Menu push (only first works)**: The menu availability toggle triggered an instant update the first time, but all subsequent changes required waiting for the 60s polling fallback.

2. **Order status push (never works)**: Order status changes never arrived via STOMP — the order tracking screen relied entirely on its 10s polling fallback, masking the bug.

### Why

**Bug 1 — SockJS long-polling fallback:**
`StompConfig.sockJS()` was used, which makes Flutter negotiate transport via SockJS. SockJS tries WebSocket first, but can silently fall back to HTTP long-polling if WebSocket fails or is unreliable on the Android emulator. HTTP long-polling works as follows: the client opens an HTTP connection, the server holds it until a message is ready, delivers the message as the HTTP response, and closes the connection. The client must immediately re-open a new poll to receive the next message. If the re-poll races with or is delayed by anything, subsequent messages are missed — which is exactly why only the first menu push arrived.

SockJS was originally added for browser clients (where raw WebSocket can be blocked by firewalls or CSP policies). The Flutter app is a native client with first-class WebSocket support and never needed SockJS.

**Bug 2 — Topic mismatch for orders:**
Flutter's `subscribeToOrder()` subscribed to `/topic/orders/{orderId}` (per-order destination). Spring Boot's `OrdersGateway.emitOrderStatusUpdate()` broadcasted to `/topic/order.status` (generic, no orderId). These never matched — no order status push was ever received by Flutter.

### Fix

**Bug 1:** Added a second `registerStompEndpoints` entry in `WebSocketConfig` — `/ws-native` — registered WITHOUT `.withSockJS()`. Changed Flutter's `SocketService` from `StompConfig.sockJS(url: 'http://...')` to `StompConfig(url: 'ws://10.0.2.2:8080/api/ws-native')`. Raw WebSocket maintains a persistent bidirectional connection; every message is delivered reliably without any re-polling logic. Also updated `SecurityConfig` to `permitAll()` on `/ws-native/**` so the WebSocket handshake isn't blocked.

**Bug 2:** Changed `emitOrderStatusUpdate()` to broadcast to BOTH `/topic/order.status` (for staff dashboard compatibility) AND `/topic/orders/{orderId}` (matching Flutter's per-order subscription). Now every order status change reaches the correct Flutter screen instantly.

---

## BF-009 — STOMP menu push never received; STOMP broken on session restore

**Files:** `gasthaus_app/lib/core/services/socket_service.dart`, `gasthaus_app/lib/features/menu/menu_provider.dart`, `gasthaus_app/lib/features/auth/auth_provider.dart`  
**Date:** 2026-04-03

### What
Menu availability changes from the dashboard never triggered an instant update in Flutter. The Flutter app never received the `/topic/menu` STOMP push — confirmed by the absence of `[STOMP] *** PUSH RECEIVED ***` in logs. Updates only arrived via the 60-second polling fallback. Order status updates (also STOMP) worked correctly.

### Why
Two independent bugs:

**Bug 1 — `subscribe()` inside `onConnect` silently fails:**
`MenuProvider` is created at app startup (in `main.dart`'s `MultiProvider`), before the user logs in and before `SocketService.connect()` is ever called. So `_isConnected=false` when `subscribeToMenu()` is called, and the callback was stored in `_callbacks` to be activated later in `_onConnect`. However, `stomp_dart_client`'s `subscribe()` behaves differently when called from *inside* the `onConnect` handler versus when called *after* it returns — the former silently fails to register the subscription with the STOMP broker server-side. The order tracking screen works because it calls `subscribeToOrder()` from `initState()`, which runs after `_onConnect` has already returned (the user opened the screen after logging in), so `_isConnected=true` and `_doSubscribe()` is called directly — a completely different code path.

**Bug 2 — `restoreSession()` never called `SocketService.connect()`:**
When the app restores a saved session (user was previously logged in), `restoreSession()` set `_currentUser` and called `notifyListeners()`, which redirected the router to `/menu`. But `SocketService.connect()` was only called in `login()`. For restored sessions, `login()` was never called, so no STOMP connection was ever established. All real-time features silently fell back to polling.

### Fix
**Bug 1:** Replaced the `_callbacks`-in-`_onConnect` subscription pattern for `MenuProvider` with a `connectListeners` mechanism. `SocketService` now has a `Map<String, VoidCallback> _connectListeners`. `_onConnect` fires these listeners after setting `_isConnected=true`. Each listener calls `subscribeToMenu()` knowing `_isConnected=true`, so `_doSubscribe()` is called immediately — the exact same code path as the order screen. `MenuProvider` registers its listener in the constructor and removes it in `dispose()`.

**Bug 2:** Added `unawaited(SocketService.instance.connect())` to `restoreSession()` when a valid token is found, mirroring what `login()` already did.

---

## BF-003 — Pull-to-refresh not working on Menu screen

**File:** `gasthaus_app/lib/features/menu/menu_screen.dart`  
**Date:** 2026-04-02

### What
Pulling down on the menu screen had no effect — no spinner, no reload.

### Why
The `CustomScrollView` had no `RefreshIndicator` wrapper, so the overscroll gesture was ignored. Also, the default `ScrollPhysics` don't guarantee overscroll when content fits the viewport, which would prevent the indicator from triggering even if it existed.

### Fix
Wrapped the `CustomScrollView` in a `RefreshIndicator` (amber spinner, calls `menu.loadMenu()`) and added `physics: AlwaysScrollableScrollPhysics()` to ensure pull-to-refresh works even when the grid has few items.

---

## BF-012 — Missing PAID status, special instructions hidden, Flutter "Done" unreachable

**Files:** `gasthaus-backend-java/.../enums/OrderStatus.java`, `gasthaus-dashboard/types/index.ts`, `gasthaus-dashboard/app/(dashboard)/orders/page.tsx`, `gasthaus_app/lib/core/models/order.dart`, `gasthaus_app/lib/features/orders/order_tracking_screen.dart`  
**Date:** 2026-04-03

### What
Three related issues: (1) special instructions (per-item notes) were never displayed in the dashboard order cards; (2) the dashboard's final status was SERVED with no further action — orders were stuck there permanently; (3) the Flutter app's "Done" stepper step was mapped to COMPLETED, a status that was never set by the dashboard, so Flutter orders never reached Done.

### Why
The `OrderItem` type has a `notes` field but the `OrderCard` component never rendered it. The SERVED column had `actionLabel: null` making it a dead end. The new intended flow (SERVED → PAID) didn't exist: PAID was absent from both the Spring Boot enum and the dashboard types. Flutter's `_statusSteps` ended with COMPLETED which the backend never emitted via the dashboard, and `isCompleted` / `isActive` didn't account for PAID.

### Fix
- **Spring Boot**: Added `PAID` to `OrderStatus` enum (between SERVED and the legacy COMPLETED).
- **Dashboard types**: Added `PAID = 'PAID'` to the `OrderStatus` enum.
- **Dashboard orders page**: Changed SERVED column to have `actionLabel: 'Mark Paid'` → `nextStatus: PAID`; added PAID as the new terminal/dimmed column; rendered item notes in an amber callout inside `OrderCard` when present.
- **Flutter `order.dart`**: `isActive` now includes SERVED (payment pending); `isCompleted` maps PAID (and legacy COMPLETED) to done.
- **Flutter `order_tracking_screen.dart`**: Replaced COMPLETED with PAID in `_statusSteps`; updated `_statusConfig` with PAID and SERVED subtitles reflecting the new flow; kept COMPLETED case for legacy order display.

---

## BF-011 — Order tracking screen shows no item names and Rs. 0 per item

**File:** `gasthaus_app/lib/core/models/order.dart`  
**Date:** 2026-04-03

### What
The order tracking screen displayed item rows with only the fork/knife fallback icon (no name, no image) and "Rs. 0" for every item price. The order total was correct.

### Why
`OrderItem.fromJson` was written for the NestJS/Prisma response shape, which flattens item details into top-level keys: `menuItemName`, `menuItemImage`, and `price`. Spring Boot serializes the `@ManyToOne MenuItem` relationship as a nested object under `menuItem`, and stores the price snapshot as `unitPrice` (the entity field name). All three reads returned `null`/0 because the keys didn't exist at the top level.

Similarly, `Order.fromJson` read `json['tableNumber']` directly, but Spring Boot nests the table under `json['table']['tableNumber']`.

### Fix
Updated `OrderItem.fromJson` to read from the nested `menuItem` object for name, image, and id, and from `unitPrice` for price — with fallbacks to the NestJS flat keys so the model works against either backend. Updated `Order.fromJson` to try `json['table']['tableNumber']` first, falling back to flat `json['tableNumber']`.

---

## BF-010 — STOMP menu push not received after logout/login cycle

**File:** `gasthaus_app/lib/core/services/socket_service.dart`  
**Date:** 2026-04-03

### What
After logging out and logging back in, menu availability changes from the dashboard produced no instant update in the Flutter app. STOMP was technically connected (logs showed `*** CONNECTED ***`), but `[STOMP] Firing 0 connectListener(s): []` confirmed no subscriptions were re-established. The server was broadcasting correctly (Java logs showed `[MENU-WS] Broadcast sent`) but Flutter never received the pushes — only the 60-second polling fallback ever updated the UI.

### Why
`disconnect()` called `_connectListeners.clear()` and `_callbacks.clear()`. `MenuProvider` registers its connect listener once at app startup in its constructor — it never re-registers. After `logout()` → `disconnect()` cleared the maps, the next `login()` → `connect()` created a new `StompClient` and `_onConnect` fired with 0 listeners and 0 callbacks. No subscription to `/topic/menu` was ever sent to the server, so all subsequent broadcasts were silently lost.

### Fix
Removed `_callbacks.clear()` and `_connectListeners.clear()` from `disconnect()`. These hold durable subscription intent from providers that live for the app's lifetime and must survive logout/login cycles. Only `_subscriptions` (connection-specific STOMP handles) is cleared on disconnect, as those cannot be reused across sessions. On the next login `_onConnect` fires → finds 1 connect listener ('menu') → calls `subscribeToMenu()` with `_isConnected=true` → `_doSubscribe()` runs immediately, same path as the working order screen.

---
