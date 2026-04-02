# Gasthaus — Complete Test Plan
## Flutter App (Customer) ↔ Next.js Dashboard (Staff)

---

## Setup & Prerequisites

Before all tests:
- Spring Boot backend running on `localhost:8080` (or NestJS on `3001`)
- PostgreSQL running
- FastAPI AI service running on `localhost:8000`
- Fresh test database (or known seed data)
- Flutter app running on emulator/device
- Next.js dashboard running in browser (`localhost:3000`)
- Have 2 devices/windows open simultaneously for parallel tests

---

## 1. Authentication Flow

### 1.1 — Customer Registration

**Flutter App:**
1. Open app → lands on `/login`
2. Tap "Create account" → lands on `/register`
3. Enter Full Name: `Test Customer`
4. Enter Email: `customer@test.com`
5. Enter Password: `test123`
6. Enter Confirm Password: `test123`
7. Tap "Create Account"
8. **Expected:** Navigates to `/menu` tab, bottom nav visible

**Validation tests (all on Register screen):**
- Submit with empty name → "Full name is required" error shown inline
- Submit with invalid email → "Enter a valid email" error
- Password under 6 chars → "Password must be at least 6 characters"
- Passwords don't match → "Passwords do not match"
- All fields valid → spinner on button while loading, then navigates

---

### 1.2 — Customer Login

**Flutter App:**
1. On `/login`, enter `customer@test.com` / `test123`
2. Tap "Sign In"
3. **Expected:** Navigates to `/menu`, bottom nav visible

**Negative cases:**
- Wrong password → red error banner appears below form
- Non-existent email → error banner appears
- Empty fields → "Email is required" / "Password is required" shown before API call

---

### 1.3 — Staff Login (Dashboard)

**Dashboard Browser:**
1. Navigate to `localhost:3000/login`
2. Log in as MANAGER with manager credentials
3. **Expected:** Redirects to `/dashboard`
4. Log out, log in as KITCHEN role
5. **Expected:** Redirects to `/kitchen` full-screen display

---

## 2. Menu Browsing ↔ Menu Management

### 2.1 — Customer Browses Menu

**Flutter App (after login):**
1. Land on `/menu` tab
2. **Expected:** Shimmer skeleton appears briefly, then 2-column grid of items
3. All category chips visible (horizontal scroll): "All" + one per category
4. Tap a category chip (e.g., "Burgers")
5. **Expected:** Grid filters to only that category's items
6. Tap "All" chip
7. **Expected:** All items visible again
8. Type "chicken" in search bar
9. **Expected:** Grid updates live to show only items matching "chicken" in name/description
10. Clear search
11. **Expected:** Full grid returns

---

### 2.2 — Staff Manages Menu (Dashboard Parallel)

**Dashboard (MANAGER role):**
1. Navigate to `/menu`
2. Left sidebar shows all categories with item counts
3. Center shows 3-column grid with all items
4. Tap a category in sidebar → grid filters to that category
5. Click "Add Item" button
6. Fill in: Name, Description, Price, select Category
7. Upload an image (drag-drop or click)
8. Click "Save Changes"
9. **Expected:** Item appears in grid and count badge on sidebar updates

**Flutter App (simultaneously):**
10. Pull-to-refresh on Menu screen (swipe down)
11. **Expected:** New item appears in grid without app restart

---

### 2.3 — Item Availability Toggle

**Dashboard:**
1. On `/menu`, click an item card → edit panel opens on right
2. Toggle the "Available" switch OFF
3. Click "Save Changes"

**Flutter App:**
4. Pull-to-refresh on Menu screen
5. **Expected:** That item is gone from the grid (unavailable items hidden from customers)

**Restore:**
6. Toggle it back ON in dashboard
7. Flutter refresh → item reappears

---

### 2.4 — Delete Item

**Dashboard:**
1. Select item → edit panel → click red "Delete" button
2. Confirm the prompt
3. **Expected:** Item removed from grid, category count decrements

**Flutter App:**
4. Refresh menu
5. **Expected:** Item no longer visible in any category

---

### 2.5 — Add & Delete Category

**Dashboard:**
1. Click "Add Category" (dashed button in left sidebar)
2. Type category name "Desserts" → submit
3. **Expected:** "Desserts" appears in sidebar with count 0

**Flutter App:**
4. Refresh menu → "Desserts" chip appears in horizontal category filter

**Dashboard:**
5. Delete "Desserts" category (hover → delete icon on sidebar)
6. **Expected:** Category removed

**Flutter App:**
7. Refresh → "Desserts" chip gone

---

## 3. Item Detail & Cart

### 3.1 — Open Item Detail Sheet

**Flutter App:**
1. On `/menu`, tap any item card
2. **Expected:** Bottom sheet slides up showing:
   - Item image (4:3 ratio)
   - Name, description
   - Category tag
   - Price
   - Quantity selector defaulting to 1
   - "Add to Cart" button
3. Tap "−" when quantity is 1
4. **Expected:** Quantity stays at 1 (can't go below 1)
5. Tap "+" three times
6. **Expected:** Quantity shows 4
7. Tap "Add to Cart"
8. **Expected:** Sheet closes, snackbar "Added to cart" appears, cart icon in top-right shows badge with count

---

### 3.2 — Add Multiple Items to Cart

**Flutter App:**
1. Add Item A (qty 2) via bottom sheet
2. Add Item B (qty 1) via quick-add "+" on card
3. Cart icon badge should show "3"
4. Tap cart icon → navigates to `/cart`
5. **Expected:**
   - "YOUR ORDER" section shows both items
   - Item A shows qty 2, Item B shows qty 1
   - Order Summary shows correct subtotal, 5% tax, total

---

### 3.3 — Cart Item Manipulation

**Flutter App (on `/cart`):**
1. Tap "+" on an item → quantity increments, total recalculates
2. Tap "−" on an item with qty 2 → goes to qty 1
3. Tap "−" on an item with qty 1
4. **Expected:** Item removed from cart
5. Swipe item left
6. **Expected:** Item dismissed/removed from cart
7. Tap delete icon in AppBar
8. **Expected:** Confirm dialog "Clear all items?" appears
9. Confirm → **Expected:** Cart empties, empty state shown with "Your cart is empty"

---

### 3.4 — Special Instructions

**Flutter App (on `/cart` with items):**
1. Tap into "SPECIAL INSTRUCTIONS" text field
2. Type "No onions please, extra spicy"
3. Verify character counter stays under 300
4. **Expected:** Text persists in field
5. Place order (see section 4) → verify special instructions reach backend

---

## 4. Order Placement ↔ Dashboard Live Feed

### 4.1 — Place Order (No Table Pre-Set)

**Flutter App:**
1. Have items in cart, no table number set (no `/menu?table=X` QR scan done)
2. Tap "Place Order · Rs. {total}"
3. **Expected:** Dialog prompts "Enter table number" with a number input
4. Enter table number "5"
5. Tap Confirm
6. **Expected:** Loading spinner on button, then navigates to `/orders/{orderId}` tracking screen

**Dashboard (MANAGER or WAITER, simultaneously watching):**
7. On `/dashboard` → "Live Orders" section
8. **Expected:** New order appears at top of list within 1-2 seconds (WebSocket push)
9. Also on `/orders` Kanban → new card appears in "PENDING" column
10. Also on `/kitchen` → new card appears with amber top bar ("New Order" state)

---

### 4.2 — Place Order (Table Pre-Set via URL)

**Flutter App:**
1. Open the app to `/menu?table=3`
2. **Expected:** Table chip "Table 3" appears below search bar on menu screen
3. Cart screen shows table chip "Table 3" in order summary
4. Tap "Place Order"
5. **Expected:** No table number dialog → order placed directly with table 3
6. Navigate to tracking screen

---

### 4.3 — Real-Time Order Tracking

**Flutter App (on `/orders/{orderId}`):**
1. Observe initial status: "Order Placed" (PENDING)
2. Stepper at first step

**Dashboard (`/kitchen` or `/orders`):**
3. Find the order card in PENDING column (or Kitchen board)
4. Click "Confirm" button on order card
5. **Expected (Flutter):** Within 2 seconds (WebSocket), status updates to "Order Confirmed"
   - Status icon changes
   - Subtitle text updates
   - Stepper advances to step 2
   - Pulsing animation changes character
6. Click "Start Preparing" (or "Prep") on dashboard
7. **Expected (Flutter):** Status updates to "Being Prepared"
   - Time chip shows "~10 min" estimate
   - Step 3 active on stepper
8. Click "Mark Ready" on dashboard
9. **Expected (Flutter):** Status updates to "Ready!" with green checkmark icon
   - Step 4 active
   - Time chip shows "Ready to pick up"
10. Click "Serve" on dashboard
11. **Expected (Flutter):** Status "Served", step 5 active
12. Click "DONE" (or "Complete") on dashboard
13. **Expected (Flutter):** Status "Completed", pulsing stops entirely, all 5 steps checked

---

### 4.4 — Dashboard Kanban Status Progression

**Dashboard only (`/orders`):**
1. Find order in PENDING column → action button says "Confirm"
2. Click "Confirm" → card moves to CONFIRMED column → button says "Prep"
3. Click "Prep" → card moves to PREPARING column → left border turns purple → button says "Ready"
4. Click "Ready" → card moves to READY column → left border turns green → button says "Serve"
5. Click "Serve" → card moves to SERVED column → button says "DONE"
6. Note column counts update on each move

---

### 4.5 — Kitchen Display Parallel Test

**Dashboard (`/kitchen`, separate window):**
1. When new order arrives: card appears with amber top bar, "Start Preparing" button
2. Timer starts counting up (MM:SS format)
3. Click "Start Preparing" → amber bar becomes blue, button becomes "Mark Ready"
4. Wait 10 minutes: bar turns red (overdue), timer pulses
5. Click "Mark Ready" → card shows "Collected ✓" disabled button, green bar
6. **Expected (Flutter):** Tracking screen reflects each status change

---

## 5. Orders History Screen

### 5.1 — View Order History

**Flutter App (after placing at least 2 orders):**
1. Tap "Orders" tab in bottom nav
2. **Expected:** Orders list shows most recent orders with:
   - Order number
   - Date/time
   - Status badge (color-coded)
   - Item thumbnail(s) overlapping
   - Total amount
3. All filter chips visible: All / Active / Completed / Cancelled

---

### 5.2 — Filter Orders

**Flutter App:**
1. Tap "Active" filter chip
2. **Expected:** Only orders in PENDING/CONFIRMED/PREPARING/READY/SERVED statuses
3. Tap "Completed" chip
4. **Expected:** Only COMPLETED orders, each with "Leave Review" link
5. Tap "Cancelled" chip
6. **Expected:** Only CANCELLED orders
7. Tap "All" → everything returns

---

### 5.3 — Pull to Refresh

**Flutter App (on Orders tab):**
1. From dashboard, advance an order's status
2. On Flutter, pull down on orders list
3. **Expected:** List refreshes, status badge updates on that order

---

### 5.4 — Navigate to Tracking from History

**Flutter App:**
1. Tap any active order card in orders list
2. **Expected:** Navigates to `/orders/{id}` tracking screen
3. Back button returns to orders list

---

## 6. Leave Review Flow ↔ Dashboard Reviews

### 6.1 — Write a Review

**Flutter App (after order is COMPLETED):**
1. Go to Orders tab, filter "Completed"
2. Find completed order → tap "Leave Review" link
3. **Expected:** Bottom sheet slides up showing:
   - First item's image + name
   - 5 empty star icons
   - Comment text field
   - Submit button (disabled until rating selected)
4. Tap 4th star → first 4 stars fill amber
5. Type "Great burger, very fresh!"
6. Tap Submit
7. **Expected:** Sheet closes, success snackbar shown

**Dashboard (`/reviews`):**
8. Refresh page (or auto-updates via React Query)
9. **Expected:** New review card appears in list with:
   - Customer name
   - Item badge
   - 4 amber stars
   - Comment text
   - Time "just now"
10. Right sidebar metrics update: total count +1, average rating recalculates

---

### 6.2 — Low Rating Review (Dashboard Highlighting)

**Flutter App:**
1. Submit a review with 2 stars

**Dashboard (`/reviews`):**
2. **Expected:** That review card has red left-border accent
3. "Sentiment" card on right sidebar: "Negative" count increments
4. "Quick Insight" card appears (or updates) with recommendation text

---

### 6.3 — Dashboard Review Filtering

**Dashboard (`/reviews`):**
1. Use "All Ratings" dropdown → select "2 ★ & below"
2. **Expected:** Only low-rated reviews shown, count updates
3. Use "Last 7 Days" filter → only recent reviews shown
4. Toggle "Latest First" / "Oldest First" → list reverses order

---

## 7. AI Waiter (Gustav) Screen

### 7.1 — Initial State

**Flutter App:**
1. Tap "AI Waiter" tab (sparkle icon)
2. **Expected:** Welcome banner visible with "Guten Tag! I'm Gustav"
3. 4 suggestion chips visible: "What's popular today?", "I'm vegetarian", "Something spicy", "Best dessert?"
4. Input bar at bottom empty, send button grayed out

---

### 7.2 — Send a Message via Suggestion Chip

**Flutter App:**
1. Tap "What's popular today?" chip
2. **Expected:**
   - Chip text fills input field (or sends immediately)
   - User bubble appears (right-aligned, amber background)
   - Typing indicator (3 dots) appears in left position
   - After response: AI bubble (left-aligned, white, "GUSTAV" label) with formatted text
   - Auto-scrolls to latest message

---

### 7.3 — Type Custom Message

**Flutter App:**
1. Type "What dishes are gluten-free?" in input field
2. Send button activates (turns amber)
3. Tap send button
4. **Expected:** Message sent, typing indicator shown, AI responds with recommendations
5. Press keyboard "Send" key → same behavior as tapping send

---

### 7.4 — Markdown Rendering in AI Response

**Flutter App:**
1. Ask "Tell me about your menu"
2. **Expected:** AI response renders:
   - Bold text as bold (no raw asterisks visible)
   - Line breaks properly spaced
   - Clean readable formatting

---

### 7.5 — Clear Chat Session

**Flutter App:**
1. After having a conversation, tap refresh/clear icon in top-right of AI screen
2. **Expected:**
   - All messages cleared
   - Welcome banner returns
   - Suggestion chips reappear
3. Session also clears on backend (`DELETE /ai/session` called)

---

### 7.6 — Session Persistence Across Tab Switches

**Flutter App:**
1. Have a conversation with Gustav
2. Switch to Menu tab, then back to AI Waiter tab
3. **Expected:** All messages still visible (global provider preserves state)

---

## 8. Profile Screen

### 8.1 — Profile Display

**Flutter App:**
1. Tap Profile tab (person icon)
2. **Expected:**
   - Dark header with avatar (amber circle, white initials from name)
   - Name displayed, role "Customer" below
   - Stats card: Total Orders / Completed / Reviews (numbers from actual data)
   - ACCOUNT section: Full Name, Email Address, Change Password
   - SUPPORT section: About Gasthaus, Terms of Service
   - LOG OUT button (red text)

---

### 8.2 — Edit Name

**Flutter App:**
1. Tap "Full Name" row
2. **Expected:** Dialog opens with current name pre-filled
3. Change to "Updated Name"
4. Tap Save
5. **Expected:** Avatar initials and displayed name update; if not wired to backend yet, dialog closes

---

### 8.3 — View Email (Read-Only)

**Flutter App:**
1. Tap "Email Address" row
2. **Expected:** Dialog shows email, no editable field (view-only), close button only

---

### 8.4 — Order Stats Accuracy

**Flutter App:**
1. Note "Total Orders" and "Completed" counts on profile
2. Place a new order from menu → complete it via dashboard
3. Return to profile tab
4. **Expected:** "Total Orders" incremented by 1, "Completed" incremented by 1

---

### 8.5 — Logout

**Flutter App:**
1. Tap "Log Out" button
2. **Expected:** Confirmation dialog appears
3. Tap Cancel → stays on profile
4. Tap Log Out again → Confirm
5. **Expected:** Navigates to `/login`, JWT cleared from storage
6. Tap back button
7. **Expected:** Cannot navigate back to profile; redirects to login
8. Close and reopen app
9. **Expected:** Lands on login screen (not auto-logged in)

---

## 9. Tables Flow (QR Scan Simulation)

### 9.1 — Table Assignment via URL

**Flutter App (simulate QR scan via deep link):**
1. Open app with URL `/menu?table=7`
2. **Expected:** "Table 7" chip appears below the search bar on menu screen
3. Add item to cart → go to Cart
4. **Expected:** "Table 7" chip visible in cart, no table-number dialog on order placement
5. Place order
6. **Expected:** Order created for table 7

**Dashboard (`/tables`):**
7. Navigate to Tables page
8. Find Table 7 tile
9. **Expected:** Table 7 now shows as Occupied (red dot, customer name, red bottom bar)
10. Detail panel on right shows: customer name, seated time counting up, bill amount

---

### 9.2 — Table Status Toggle (Dashboard)

**Dashboard:**
1. Select an occupied table → "Mark as Available" button in detail panel
2. Click it
3. **Expected:** Table tile changes from red occupied style to dashed available style

---

### 9.3 — Dashboard Tables Overview

**Dashboard (`/dashboard` overview page):**
1. Stat card "Active Tables" shows occupied/total count
2. Mini table map shows same occupancy state as `/tables` page
3. As orders are placed and completed, this count updates live

---

## 10. Manager Insights (Dashboard Only)

### 10.1 — Generate AI Insights

**Dashboard (`/insights`, MANAGER role):**
1. Navigate to `/insights`
2. Select period "Today"
3. Click "Generate Insights" button
4. **Expected:** Loading state shown, then AI-generated insights text appears in card
5. Switch to "This Week" → click regenerate
6. **Expected:** Different insights text reflecting weekly data

---

### 10.2 — Charts Render Correctly

**Dashboard:**
1. Hourly Orders bar chart shows bars for each hour with orders
2. Revenue area chart shows trend over selected period
3. Top Items horizontal list shows ranked items with order counts
4. All 4 metric cards (Avg Order Value, Total Revenue, Customer Satisfaction, Avg Fulfillment Time) show non-zero values after orders are placed

---

## 11. Real-Time (WebSocket) Parallel Tests

### 11.1 — Multi-Device Order Notification

**Setup:** Dashboard open in 2 browser tabs simultaneously

**Tab 1 (Dashboard):** On `/dashboard` overview page  
**Tab 2 (Kitchen):** On `/kitchen`

**Flutter App:**
1. Place new order

**Expected both tabs simultaneously:**
- Tab 1: New row in "Live Orders" section within 1-2 seconds
- Tab 2: New card in kitchen board within 1-2 seconds (amber bar)
- No page refresh needed on either tab

---

### 11.2 — Status Update Propagates to All Clients

**Setup:** Flutter tracking screen open + Dashboard `/orders` open + Dashboard `/kitchen` open

**From Kitchen:**
1. Click "Mark Ready" on an order

**Expected simultaneously:**
- Flutter tracking screen: status jumps to "Ready!", stepper at step 4
- Dashboard `/orders` Kanban: card moves to READY column, left border turns green
- Dashboard `/kitchen`: card shows green bar, "Collected ✓" button

---

### 11.3 — Fallback Polling (WebSocket Disconnected)

**Flutter App:**
1. Open order tracking screen
2. Disable network briefly (airplane mode), then re-enable
3. **Expected:** Polling (10s interval) picks up latest status once network returns, no manual refresh needed

---

## 12. Edge Cases & Error Handling

### 12.1 — Empty States

| Screen | Trigger | Expected UI |
|---|---|---|
| Orders tab | No orders placed yet | "No orders yet" empty state |
| AI Waiter | Before any message sent | Welcome banner + suggestion chips |
| Cart | No items added | "Your cart is empty" + link back to menu |
| Menu grid | Category with no items | "No items found" state |
| Dashboard orders | No orders today | Empty kanban columns |

---

### 12.2 — Error States

**Flutter App:**
1. Kill backend server → Menu screen shows error state with "Retry" button
2. Tap Retry → re-fetches and recovers when backend is back
3. Place order with network offline → error feedback shown to user (snackbar or dialog)

---

### 12.3 — Long Content

- Add menu item with very long name/description → check text wrapping in item cards and bottom sheet
- Place order with 300-char special instructions → verify counter reaches limit, submission succeeds

---

### 12.4 — Concurrent Orders

1. Place order 1, do not complete it
2. Place order 2 immediately after
3. Orders tab shows both with correct statuses
4. Dashboard shows both orders in their respective Kanban columns
5. Advance order 1 to READY — order 2 stays PENDING
6. Verify Flutter tracking screen for order 1 shows READY while order 2 is unaffected
7. Complete both orders independently

---

### 12.5 — Dashboard Search & Filters

**Dashboard (`/orders`):**
1. Type customer name in search → only that customer's orders shown
2. Type table number → only that table's orders shown
3. Toggle "Today" / "This Week" → verify order counts change appropriately
4. Clear search → all orders return

---

## 13. Staff Accounts (Dashboard Only)

### 13.1 — Create New Staff

**Dashboard (`/staff`, MANAGER role):**
1. Click "Add Staff"
2. Fill in: Name `Test Waiter`, Email `waiter@test.com`, Password `test123`, Role `KITCHEN`
3. Click "Create Account"
4. **Expected:** New staff card appears under "Kitchen Staff" section with name, email, role badge

---

### 13.2 — Create Manager Account

**Dashboard (`/staff`):**
1. Click "Add Staff"
2. Fill in: Name `Test Manager`, Email `manager2@test.com`, Password `test123`, Role `MANAGER`
3. Click "Create Account"
4. **Expected:** New staff card appears under "Managers" section

---

### 13.3 — Login as New Staff

**Dashboard (new browser window or incognito):**
1. Login with `waiter@test.com` / `test123`
2. **Expected:** Redirects to `/kitchen` (KITCHEN role lands on kitchen display)
3. Login with `manager2@test.com` / `test123`
4. **Expected:** Redirects to `/dashboard`

---

## Recommended Test Execution Order

```
1.  Register customer (Flutter)
2.  Login as Manager (Dashboard)
3.  Add menu items + categories (Dashboard) → verify on Flutter
4.  Browse menu, use search and category filters (Flutter)
5.  Add items to cart, manipulate quantities (Flutter)
6.  Place order as customer (Flutter) → verify on Dashboard live feed
7.  Advance order through all statuses (Dashboard) → verify on Flutter tracking screen
8.  Test kitchen display parallel with Flutter tracking (Dashboard + Flutter)
9.  View order history + filters (Flutter)
10. Leave review on completed order (Flutter) → verify on Dashboard reviews
11. Test AI Waiter conversation + suggestion chips (Flutter)
12. Test profile stats accuracy after orders (Flutter)
13. Test table assignment via URL param (Flutter) → verify on Dashboard tables
14. Generate AI insights with real data (Dashboard)
15. Create staff accounts + test role-based login (Dashboard)
16. Run concurrent orders test (Flutter x2 + Dashboard)
```

---

## Key Things to Watch For

| Potential Issue | Where to Check |
|---|---|
| WebSocket latency > 3s | Order tracking screen + kitchen display |
| Status badge colors wrong | Orders list + Kanban columns |
| Cart totals miscalculated (tax) | Cart screen summary card |
| Pulsing animation doesn't stop at terminal status | Order tracking when COMPLETED/CANCELLED |
| Category filter count mismatch | Menu sidebar (dashboard) |
| Review stats don't update after submission | Reviews right sidebar averages |
| GoRouter back stack broken after order placement | Back button from tracking screen |
| Profile stats stale | After completing orders, profile tab |
| AI session persists after clear | AI waiter refresh button |
| Table chip missing from cart | After QR/URL table assignment |
| Kitchen timer resets unexpectedly | Kitchen display during long orders |
| Empty state flashes before data loads | Menu, orders, reviews pages |
