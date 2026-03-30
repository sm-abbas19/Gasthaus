# Gasthaus Flutter App — Implementation Plan

## Overview

Customer-facing Flutter app connecting to the Spring Boot backend (localhost:8080).
All 10 screens have Stitch-generated HTML designs in `flutter-stitch-designs/`.
Dependencies already declared in `pubspec.yaml` — no additions needed.

**Backend base URL:** `http://localhost:8080/api`
**Auth:** JWT Bearer token stored in `flutter_secure_storage`
**Role:** CUSTOMER only (this app is not for staff)

---

## Design Token Reference (from stitch prompts)

| Token | Value |
|---|---|
| Background | `#F9F9F7` |
| Card/Surface | `#FFFFFF` |
| Primary Amber | `#D97706` |
| Amber Pressed | `#B45309` |
| Dark Surface | `#1C1C1E` |
| Text Primary | `#111827` |
| Text Secondary | `#6B7280` |
| Text Muted | `#9CA3AF` |
| Border | `#E5E7EB` |
| Divider | `#F3F4F6` |
| Success | `#16A34A` |
| Error | `#DC2626` |

> Note: `amber_ash/DESIGN.md` is Stitch's internal design philosophy and conflicts with our token spec above. Always follow the stitch-prompts token spec, not the DESIGN.md deviations.

---

## Phase 1 — Foundation (Infrastructure)

**Goal:** Running app with correct theme, routing, and API layer. No real screens yet.

### 1.1 — Theme & Design System (`lib/core/theme/`)
- `app_colors.dart` — all color constants as `Color` values
- `app_text_styles.dart` — all typography constants (`TextStyle`)
- `app_theme.dart` — `ThemeData` wired up with Inter font, colors, input decoration theme, button themes, card theme

### 1.2 — API Service (`lib/core/services/`)
- `api_service.dart` — Dio singleton with:
  - Base URL `http://localhost:8080/api`
  - Request interceptor: attaches `Authorization: Bearer <token>` from secure storage
  - Response interceptor: throws typed `ApiException` on 4xx/5xx
- `auth_storage.dart` — thin wrapper over `flutter_secure_storage` for token + user JSON

### 1.3 — Auth Provider (`lib/core/providers/`)
- `auth_provider.dart` — `ChangeNotifier` holding:
  - `User? currentUser`
  - `bool isLoggedIn`
  - `login(email, password)` → calls `POST /auth/login`, stores token + user
  - `register(name, email, password)` → calls `POST /auth/register`
  - `logout()` → clears storage, resets state
  - `restoreSession()` → reads token + user from storage on app start

### 1.4 — Router (`lib/core/router/`)
- `app_router.dart` — `GoRouter` with:
  - Redirect logic: unauthenticated → `/login`
  - Routes: `/login`, `/register`, `/menu` (shell), `/menu/item/:id`, `/cart`, `/orders`, `/orders/:id`, `/ai-waiter`, `/profile`
  - `ShellRoute` for bottom nav tabs

### 1.5 — Main App Wiring (`lib/main.dart`)
- `MultiProvider` wrapping `MaterialApp.router`
- Call `restoreSession()` before `runApp`
- Register `AuthProvider`, `CartProvider` (stub)

---

## Phase 2 — Auth Screens

**Reference designs:** `login_screen/`, `register_screen/`

### 2.1 — Login Screen (`lib/features/auth/login_screen.dart`)
- Gasthaus wordmark (flame icon + "GASTHAUS" text) floating above card
- Tagline: "Your table is waiting."
- White card with `EMAIL` + `PASSWORD` fields
- Primary amber "Sign In" button
- "Don't have an account? Create one" link → `/register`
- On success: `GoRouter.go('/menu')`
- Loading state on button, error snackbar on failure

### 2.2 — Register Screen (`lib/features/auth/register_screen.dart`)
- Same wordmark + card structure
- Four fields: Full Name, Email, Password, Confirm Password (with eye toggles)
- Validation: confirm password match, min 6 chars
- Primary amber "Create Account" button
- "Already have an account? Sign in" link

---

## Phase 3 — Home / Menu

**Reference designs:** `home_menu/`, `item_detail_sheet/`

### 3.1 — Menu Provider (`lib/features/menu/menu_provider.dart`)
- Fetches `GET /menu/categories` (returns categories with items nested)
- State: `List<Category> categories`, `String selectedCategoryId`, `String searchQuery`
- Computed getter: `filteredItems` — filters by category + search

### 3.2 — Bottom Nav Shell (`lib/core/widgets/main_shell.dart`)
- `Scaffold` with `bottomNavigationBar`
- Dark `#1C1C1E` background, 64px height
- 4 tabs: Menu, Orders, AI Waiter, Profile
- Active: `#D97706` icon + label, inactive: `#6B7280`
- Tab icons: 22px outlined style via `Icons` package

### 3.3 — Home/Menu Screen (`lib/features/menu/menu_screen.dart`)
- Dark header with wordmark + cart icon (amber badge showing count)
- Greeting area: "Good afternoon, / What would you like?"
- Table indicator chip (amber pill, reads from `AuthProvider.currentUser.tableNumber` — passed as query param at login or from QR scan — for now hardcode or store in provider)
- Search bar
- Horizontally scrollable category chips
- 2-column grid of `MenuItemCard` widgets
- Tapping a card opens `ItemDetailSheet`

### 3.4 — Menu Item Card (`lib/features/menu/widgets/menu_item_card.dart`)
- Food image (4:3, `CachedNetworkImage`, 12px top radius)
- Available/Unavailable badge (top-right of image)
- Name (14px bold, truncated) + price (amber)
- Circular amber "+" button → adds to cart

### 3.5 — Item Detail Bottom Sheet (`lib/features/menu/item_detail_sheet.dart`)
- `showModalBottomSheet` with `isScrollControlled: true`
- Drag handle + full-width 200px food image + close button
- Name, rating row, price, description with "Read more"
- AI Review Summary block (amber tinted, calls `POST /ai/review-summary` lazily)
- Quantity selector + "Add to Cart · Rs. X" button pinned at bottom

---

## Phase 4 — Cart & Order Placement

**Reference designs:** `cart_order_summary/`, `order_tracking/`

### 4.1 — Cart Provider (`lib/features/cart/cart_provider.dart`)
- State: `List<CartItem>` (item + quantity)
- Methods: `addItem`, `removeItem`, `updateQuantity`, `clear`
- Computed: `subtotal`, `tax (5%)`, `total`, `itemCount`
- Persisted in memory (no need for local DB — order is placed in same session)

### 4.2 — Cart Screen (`lib/features/cart/cart_screen.dart`)
- White top bar: back arrow + "Your Cart" + trash icon
- Table confirmation chip
- Cart item cards with quantity selectors + swipe-to-delete
- Special instructions multiline input
- Order summary card (subtotal, tax, total)
- Sticky "Place Order · Rs. X" button
- On place order: `POST /orders` → navigate to `/orders/:id`

### 4.3 — Order Tracking Screen (`lib/features/orders/order_tracking_screen.dart`)
- Dark top bar "Order #XXXX"
- Status hero card: animated icon + status label + time chip
- Horizontal progress stepper (5 steps)
- Order items list with totals
- "View Menu" secondary button
- Real-time updates via Socket.io `order:status` event
- Polls `GET /orders/:id` as fallback if socket not connected

---

## Phase 5 — My Orders & Reviews

**Reference designs:** `order_history/`, `write_review_sheet/`

### 5.1 — Orders Provider (`lib/features/orders/orders_provider.dart`)
- Fetches `GET /orders/my`
- State: `List<Order> orders`, `String selectedFilter`
- Computed: `filteredOrders` by status filter

### 5.2 — My Orders Screen (`lib/features/orders/orders_screen.dart`)
- "My Orders" title (main tab — no back arrow)
- Filter chips: All, Active, Completed, Cancelled
- Order cards with status badges (color-coded per status spec)
- Item thumbnails stack (3 max, overlapping)
- "Leave Review" pill button on COMPLETED orders → opens `WriteReviewSheet`
- Empty state: receipt icon + "No orders yet"

### 5.3 — Write Review Bottom Sheet (`lib/features/reviews/write_review_sheet.dart`)
- `showModalBottomSheet`
- "Leave a Review" title + item name subtitle
- 5-star rating selector (`flutter_rating_bar`) with label ("Excellent", "Good"…)
- Comment input (120px, 500 char limit with counter)
- "Submit Review" button: disabled until ≥1 star selected
- Calls `POST /reviews` with `{ menuItemId, orderId, rating, comment }`

---

## Phase 6 — AI Waiter Chat

**Reference design:** `ai_waiter_chat/`

### 6.1 — AI Chat Provider (`lib/features/ai/ai_chat_provider.dart`)
- State: `List<ChatMessage>` (role: user/ai, text, timestamp)
- `sendMessage(text)`:
  1. Appends user message
  2. Sets `isTyping = true`
  3. Calls `POST /ai/recommend` with `{ message }`
  4. Appends AI response, clears typing
- `clearSession()` → calls `DELETE /ai/session` + clears local list

### 6.2 — AI Waiter Screen (`lib/features/ai/ai_waiter_screen.dart`)
- Dark top bar: sparkle icon + "AI Waiter" + clear button
- Welcome banner (shown when messages empty): suggestion chips
- Chat message list (user bubbles right/amber, AI bubbles left/white)
- Typing indicator (3 animated dots)
- Bottom input: text field + circular send button (disabled when empty)
- Keyboard-aware: `resizeToAvoidBottomInset: true`, auto-scroll on new message

---

## Phase 7 — Profile

**Reference design:** `profile/`

### 7.1 — Profile Screen (`lib/features/profile/profile_screen.dart`)
- Dark top area: avatar (initials circle) + name + "Customer" role
- Stats card: Orders count, Reviews count, Avg rating (fetched from provider)
- Account section: Full Name, Email Address, Change Password rows (each navigates to edit dialog)
- Support section: About Gasthaus, Terms of Service (static content dialogs)
- Danger section: "Log Out" in red → calls `AuthProvider.logout()` → redirect to `/login`

### 7.2 — Profile Provider (`lib/features/profile/profile_provider.dart`)
- `GET /auth/me` to refresh user data
- Tracks order count + review count (derived from orders/reviews fetched elsewhere)

---

## Phase 8 — Real-time & Polish

### 8.1 — STOMP WebSocket Integration (`lib/core/services/socket_service.dart`)
- Spring Boot uses STOMP over WebSocket, **not** Socket.io — `socket_io_client` in pubspec is unused; add `stomp_dart_client` instead
- Connects to `ws://localhost:8080/ws`
- Authenticates with JWT token via STOMP `connect` headers
- Subscribes to `/topic/orders/{orderId}` → notifies `OrdersProvider` to update order status
- Subscribes to `/user/queue/order-ready` → shows snackbar "Your order is ready!"
- Reconnection logic with exponential backoff

### 8.2 — Shimmer Loading States
- Apply `shimmer` package to:
  - Menu item grid while loading
  - Order cards while loading
  - Profile stats while loading

### 8.3 — Error Handling
- Global `ApiException` handler in Dio interceptor
- 401 → auto logout + redirect to login
- Network error → retry snackbar
- Each screen shows inline error widget with retry button

### 8.4 — Image Handling
- All `CachedNetworkImage` widgets get placeholder shimmer + error fallback (gray rectangle with fork icon)
- Food images: `BoxFit.cover`, 4:3 aspect ratio enforced via `AspectRatio` widget

### 8.5 — Table Number Flow
- Table number is passed as a query param when the customer scans a QR code: `/menu?table=4`
- `GoRouter` reads this and stores in `CartProvider`
- Displayed as the amber chip on menu + cart screens
- Included in `POST /orders` body as `tableNumber`

---

## File Structure

```
lib/
├── main.dart
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_theme.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── auth_storage.dart
│   │   └── socket_service.dart
│   ├── router/
│   │   └── app_router.dart
│   ├── widgets/
│   │   ├── main_shell.dart          ← bottom nav shell
│   │   ├── gasthaus_wordmark.dart   ← reusable brand widget
│   │   ├── primary_button.dart
│   │   ├── app_text_field.dart
│   │   └── status_badge.dart
│   └── models/
│       ├── user.dart
│       ├── menu_item.dart
│       ├── category.dart
│       ├── order.dart
│       ├── cart_item.dart
│       └── review.dart
├── features/
│   ├── auth/
│   │   ├── auth_provider.dart
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── menu/
│   │   ├── menu_provider.dart
│   │   ├── menu_screen.dart
│   │   ├── item_detail_sheet.dart
│   │   └── widgets/
│   │       └── menu_item_card.dart
│   ├── cart/
│   │   ├── cart_provider.dart
│   │   └── cart_screen.dart
│   ├── orders/
│   │   ├── orders_provider.dart
│   │   ├── orders_screen.dart
│   │   └── order_tracking_screen.dart
│   ├── reviews/
│   │   └── write_review_sheet.dart
│   ├── ai/
│   │   ├── ai_chat_provider.dart
│   │   └── ai_waiter_screen.dart
│   └── profile/
│       ├── profile_provider.dart
│       └── profile_screen.dart
```

---

## Phase Sequence Summary

| Phase | Deliverable | Key Files |
|---|---|---|
| 1 | Theme, API, Auth, Router | `core/` foundation |
| 2 | Login + Register screens | `auth/` |
| 3 | Menu screen + Item detail sheet | `menu/` |
| 4 | Cart screen + Order tracking | `cart/`, `orders/order_tracking_screen.dart` |
| 5 | My Orders + Write Review | `orders/orders_screen.dart`, `reviews/` |
| 6 | AI Waiter chat | `ai/` |
| 7 | Profile screen | `profile/` |
| 8 | Sockets, shimmer, error handling | `core/services/socket_service.dart`, polish pass |

---

## Code Comments Policy

Every Dart file written for this app must include inline comments that:
- Explain **what** the code does and **why** that approach was chosen
- Clarify Flutter/Dart-specific concepts (e.g. `BuildContext`, `ChangeNotifier`, `initState`, widget lifecycle)
- Compare to equivalent patterns in other languages/frameworks where it helps understanding
- Flag non-obvious decisions (e.g. why `context.go()` vs `context.push()`, why `flutter_secure_storage` over `SharedPreferences`)

The goal is that reading the code teaches Flutter, not just completes the feature.

---

## Key Implementation Notes

- **State management:** `provider` package only. One `ChangeNotifier` per feature domain.
- **Navigation:** `go_router` v17. Use `context.go()` for tab switches, `context.push()` for sheets/detail screens.
- **No local DB:** Cart state is in-memory `ChangeNotifier`. Orders come from the API.
- **Image upload:** Not needed in the customer app (that's a MANAGER feature in the dashboard).
- **`flutter_secure_storage`** stores the JWT token. Regular `SharedPreferences` is not used.
- **Inter font** is loaded via `google_fonts` package — no need to bundle font files.
- **Bottom sheets** (`ItemDetailSheet`, `WriteReviewSheet`) are shown with `showModalBottomSheet`, not pushed as routes.
- **All prices** displayed in `Rs.` (Pakistani Rupee) format using `intl` package `NumberFormat`.
