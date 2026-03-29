# Gasthaus Flutter App — Stitch Design Prompts

## Design Language (applies to all screens)

**Brand:** Gasthaus — a modern, upscale casual restaurant.
**Personality:** Warm, clean, appetizing. Not a fast-food app. Not overly luxurious either. Think premium bistro.
**Platform:** Mobile (iOS + Android), portrait orientation only.

**Color Palette:**
- Background: #F9F9F7 (warm off-white, never pure white)
- Card/Surface: #FFFFFF
- Primary Accent: #D97706 (warm amber — buttons, active states, highlights)
- Accent Dark (pressed state): #B45309
- Text Primary: #111827 (near-black)
- Text Secondary: #6B7280 (medium gray)
- Text Muted: #9CA3AF (light gray, captions, placeholders)
- Border: #E5E7EB (very light gray)
- Divider: #F3F4F6
- Success: #16A34A
- Error: #DC2626
- Dark surface (bottom nav, header): #1C1C1E

**Typography:**
- Font: Inter (all weights)
- Screen titles: 22px, weight 700, #111827
- Section headers: 13px, weight 700, uppercase, letter-spacing 0.08em, #9CA3AF
- Body text: 15px, weight 400, #111827
- Secondary body: 13px, weight 400, #6B7280
- Captions: 11px, weight 400, #9CA3AF
- Button text: 15px, weight 600
- Price text: 16px, weight 700, #D97706

**Shapes & Borders:**
- Cards: 12px border radius
- Buttons (primary): 10px border radius, full-width
- Chips/badges: 20px border radius (pill shape)
- Input fields: 10px border radius, 1px solid #E5E7EB border
- Bottom sheets: 20px top border radius
- No drop shadows anywhere. Use 1px #E5E7EB borders for card separation instead.

**Spacing:**
- Screen horizontal padding: 20px on each side
- Card internal padding: 16px
- Section vertical gap: 24px
- Item list gap: 12px

**Icons:** Outlined style, 22px size, stroke weight 1.8px. Use Lucide icon set as reference.

**Images:** All food images are rectangular with 12px border radius, aspect ratio 4:3. Never circular food images.

**Bottom Navigation Bar:**
- Background: #1C1C1E (dark, same as dashboard sidebar)
- Height: 64px
- Active icon + label: #D97706
- Inactive icon + label: #6B7280
- No top border, no shadow — the dark background creates separation naturally
- Icons: 22px, labels: 10px weight 600 uppercase

**Status Bar:** Light content (white icons) on dark background.

**Buttons:**
- Primary: full-width, 52px height, #D97706 background, white text, 10px radius
- Secondary: full-width, 52px height, white background, 1px #E5E7EB border, #111827 text
- Destructive: full-width, 52px height, #FEF2F2 background, #DC2626 text
- Disabled: opacity 0.4

**Input Fields:**
- Height: 52px
- Border: 1px solid #E5E7EB, 10px radius
- Focus border: 1px solid #D97706
- Label: 11px uppercase bold #6B7280 above the field
- Placeholder: #9CA3AF

---

## Screen 1 — Login

**Prompt:**

Design a mobile login screen for Gasthaus, a restaurant app. Background is #F9F9F7 warm off-white.

At the very top center, place the Gasthaus wordmark: a small flame or utensils icon in #D97706 amber, followed by the text "GASTHAUS" in Inter font, weight 800, letter-spacing 0.3em, size 18px, color #111827. Below the wordmark, a tagline in 13px #9CA3AF that reads "Your table is waiting."

Below that, a section header in 13px bold uppercase #9CA3AF tracking widest that reads "SIGN IN". Then two input fields stacked vertically with 12px gap:
- Email field: label "EMAIL" above, placeholder "you@example.com"
- Password field: label "PASSWORD" above, placeholder "••••••••", with a small eye icon on the right to toggle visibility

Below the inputs, a full-width primary amber button labeled "Sign In" (52px tall, #D97706, white text, 10px radius).

Below the button, centered text: "Don't have an account?" in 13px #6B7280, then "Create one" as a tappable link in #D97706 same size, inline.

No hero image. No illustration. No gradient background. Keep it minimal and centered vertically on the screen. Total form width matches screen padding (20px each side). The entire form sits in a white card with 16px padding and 12px radius, centered on the #F9F9F7 background with a subtle 1px #E5E7EB border. Above the card, the wordmark floats on the background directly.

---

## Screen 2 — Register

**Prompt:**

Design a mobile registration screen for Gasthaus restaurant app. Same background #F9F9F7 as login.

At top center: same Gasthaus wordmark (flame/utensils icon in #D97706 + "GASTHAUS" text in Inter 800 uppercase wide tracking, #111827). Tagline below: "Create your account."

A white card (1px #E5E7EB border, 12px radius, 16px padding) contains a form with a section header "CREATE ACCOUNT" in 11px bold uppercase #9CA3AF above it.

Four stacked input fields with 12px gap:
- Full Name: label "FULL NAME", placeholder "Ahmed Al-Hassan"
- Email: label "EMAIL", placeholder "you@example.com"
- Password: label "PASSWORD", placeholder "Min. 6 characters", eye toggle icon on right
- Confirm Password: label "CONFIRM PASSWORD", placeholder "Repeat password", eye toggle icon on right

Full-width primary amber "Create Account" button below (52px, #D97706, white text, 10px radius).

Below the button, centered: "Already have an account?" in 13px #6B7280, then "Sign in" tappable link in #D97706.

No illustration, no gradient. Clean and form-focused. Same spacing as Login screen.

---

## Screen 3 — Home / Menu

**Prompt:**

Design the main menu browsing screen for a mobile restaurant app called Gasthaus.

**Top area:** A dark header (#1C1C1E) with 20px horizontal padding, 64px tall. Left side: a small amber flame icon and "GASTHAUS" wordmark in white text Inter 700. Right side: a shopping cart icon (outlined, 22px, white) with a small amber circular badge showing the item count (14px, white text, #D97706 background).

**Below header:** A warm greeting area on #F9F9F7 background, 20px padding. Two lines: "Good afternoon," in 13px #9CA3AF, and "What would you like?" in 22px bold #111827.

**Table indicator:** A small pill/chip below the greeting — rounded pill shape, #FEF3C7 background (light amber), #D97706 text, "Table 4" with a small table icon to the left. 11px text, bold.

**Search bar:** Full-width search input, 44px tall, #FFFFFF background, 1px #E5E7EB border, 10px radius. Left: magnifier icon in #9CA3AF. Placeholder: "Search dishes…" in #9CA3AF.

**Category chips row:** Horizontally scrollable row of pill-shaped category filter chips. Each chip: 32px tall, 14px Inter 600, 16px horizontal padding, 20px radius.
- Selected chip: #1C1C1E background, white text
- Unselected chip: #FFFFFF background, #6B7280 text, 1px #E5E7EB border
Categories shown: All, Starters, Mains, Grills, Pasta, Desserts, Drinks

**Menu items grid:** 2-column grid, 12px gap between items. Each item card:
- White background (#FFFFFF), 12px radius, 1px #E5E7EB border
- Top: food image, 4:3 ratio, 12px top radius only, full card width
- A small "Available" green badge (top-right corner of image, overlaid): #DCFCE7 background, #16A34A text, 9px bold, pill shape, 4px padding
- If unavailable: #F3F4F6 background badge, #9CA3AF text "Unavailable"
- Below image: 12px padding area. Item name in 14px bold #111827. 1 line truncated.
- Price in 15px bold #D97706 below name.
- A small circular amber "+" button (32px, #D97706 background, white plus icon 16px) in the bottom-right corner of the card's lower section.

**Bottom navigation bar:** 64px, #1C1C1E background. 4 tabs: Menu (active, #D97706), Orders, AI Waiter, Profile. Each: outlined icon 22px + label 10px bold uppercase below. Active tab icon and label in #D97706, inactive in #6B7280.

---

## Screen 4 — Item Detail

**Prompt:**

Design an item detail bottom sheet (modal sheet) for a restaurant app called Gasthaus. It slides up from the bottom covering about 85% of the screen. Background behind it is dimmed (rgba 0,0,0,0.4).

**Sheet:** White background, 20px top-left and top-right border radius.

**Top of sheet:** A drag handle — small 40px × 4px rounded bar, #E5E7EB, centered at the very top (8px from top edge).

**Food image:** Full-width image inside the sheet, 200px tall, with 0px radius (fits flush against the rounded top). On the top-right corner of the image, a close (X) button: 32px circle, white background with slight opacity, #111827 X icon, 8px from top and right edge.

**Content area (20px horizontal padding, 20px top padding):**

Item name: 22px bold #111827, 2 lines max.

Rating row below name: A filled amber star icon (16px, #D97706) + "4.6" in 14px bold #111827 + "(124 reviews)" in 13px #9CA3AF — all inline.

Price: 24px bold #D97706 on the next line.

Description: 14px #6B7280, up to 3 lines, then "Read more" link in #D97706.

**AI Review Summary section:** A soft amber-tinted block (#FFFBEB background, 1px #FDE68A border, 10px radius, 12px padding). A small sparkle/star icon in #D97706 followed by "AI Summary" label in 11px bold uppercase #D97706. Below: 13px #6B7280 italic summary text (2-3 sentences).

**Quantity selector + Add to Cart row (pinned to bottom of sheet, above safe area):**
- Left side: quantity selector — minus button (32px circle, #F3F4F6 background, #111827 text) — quantity number in 16px bold #111827 — plus button (32px circle, #D97706 background, white text)
- Right side: "Add to Cart" button, grows to fill remaining width, 52px tall, #D97706 background, white text 15px bold, 10px radius. Shows total price inline: "Add to Cart · Rs. 1,200"

---

## Screen 5 — Cart

**Prompt:**

Design a cart/order summary screen for a mobile restaurant app called Gasthaus.

**Top bar:** White background, 56px tall. Left: back arrow icon (22px, #111827). Center: "Your Cart" in 17px bold #111827. Right: empty or a trash icon if cart has items.

**Body background:** #F9F9F7.

**Table confirmation chip** (same as home screen): pill shape, #FEF3C7 background, #D97706 text, "Table 4" with table icon. 12px margin from top.

**Cart items list:** Each item in a white card (12px radius, 1px #E5E7EB border, 16px padding, 12px margin bottom):
- Left: food image thumbnail, 64×64px, 8px radius
- Right of image: Item name in 14px bold #111827. Below: price per item in 13px #9CA3AF.
- Bottom row of card: quantity selector (minus — number — plus, same style as item detail screen, compact 28px circles) on left. Item total price (quantity × price) in 15px bold #D97706 on right.
- Swipe left to reveal a red delete action (or a small trash icon top-right of card).

**Order notes input** below the list: white card (12px radius, 1px #E5E7EB border). Label "SPECIAL INSTRUCTIONS" in 11px bold uppercase #9CA3AF. A multiline text area, 80px tall, 13px #111827 placeholder "Any allergies or special requests?".

**Order summary card:** White card at the bottom of the scroll area.
- Row: "Subtotal" left, amount right in #111827 14px
- Divider line #F3F4F6
- Row: "Tax (5%)" left, amount right in #6B7280 13px
- Thick divider
- Row: "Total" left in 16px bold #111827, total amount right in 18px bold #D97706

**Bottom sticky area** (white background, 1px #E5E7EB top border, 20px padding, safe area aware):
Full-width amber "Place Order" button, 52px, #D97706, white text "Place Order · Rs. 2,400", 10px radius.

---

## Screen 6 — Order Tracking

**Prompt:**

Design an order tracking screen for a mobile restaurant app called Gasthaus. This screen appears after placing an order.

**Top bar:** #1C1C1E dark background, 56px. Left: back icon (white). Center: "Order #1042" in 17px bold white. Right: empty.

**Body background:** #F9F9F7.

**Status hero card** (20px horizontal margin, 20px top margin): White card, 12px radius, 1px #E5E7EB border, 20px padding, centered content.
- A large animated icon in the center (64px): a pulsing amber circle with a relevant icon inside — chef hat for PREPARING, check for READY, etc.
- Below icon: current status label in 20px bold #111827, e.g. "Being Prepared"
- Subtitle in 14px #6B7280: "Our kitchen is working on your order"
- Estimated time chip below: pill shape, #FEF3C7 background, #D97706 text, "~15 min remaining"

**Progress stepper** (inside the same card below a divider): Horizontal stepper with 5 steps.
Steps: Confirmed → Preparing → Ready → Served → Done
- Completed steps: filled amber circle (#D97706) with white checkmark, connected by solid amber line
- Current step: filled amber circle with white animated pulse ring, step label in #D97706 12px bold
- Future steps: hollow circle #E5E7EB, step label in #9CA3AF 12px
- Step labels below each circle: 10px, centered

**Order items section** (20px horizontal margin, 16px top): Section header "YOUR ORDER" in 11px bold uppercase #9CA3AF. White card with list of ordered items:
- Each row: item name (14px #111827) left, "×2" quantity in #9CA3AF right, price in #D97706 right.
- Dividers between rows.

**Total row** at bottom of order items card: "Total" bold 15px left, total in #D97706 bold 16px right.

**Bottom:** Full-width secondary button "View Menu" with outlined style (#FFFFFF background, 1px #E5E7EB border, #111827 text). 20px margin from edges.

**Bottom navigation bar:** Same 4-tab dark nav bar. "Orders" tab is active (#D97706).

---

## Screen 7 — My Orders

**Prompt:**

Design an order history screen for a mobile restaurant app called Gasthaus.

**Top bar:** White background, 56px. No back arrow. Title "My Orders" in 22px bold #111827 left-aligned (20px padding). This is a main tab screen.

**Body background:** #F9F9F7.

**Filter chips row:** Horizontally scrollable, same pill chip style as menu categories. Chips: All, Active, Completed, Cancelled. Selected chip: #1C1C1E background, white text. Unselected: white background, #E5E7EB border, #6B7280 text.

**Order cards list** (20px horizontal padding, 12px gap):

Each order card: White background, 12px radius, 1px #E5E7EB border, 16px padding.

Top row of card:
- Left: "Order #1042" in 14px bold #111827
- Right: status badge (pill, 20px radius). Color per status:
  - PENDING: #F3F4F6 bg, #6B7280 text
  - CONFIRMED: #EFF6FF bg, #3B82F6 text
  - PREPARING: #FEF3C7 bg, #D97706 text
  - READY: #ECFDF5 bg, #16A34A text
  - SERVED: #F0FDF4 bg, #15803D text
  - COMPLETED: #F9FAFB bg, #374151 text
  - CANCELLED: #FEF2F2 bg, #DC2626 text

Below top row: Order date and time in 12px #9CA3AF.

Items summary row: small food thumbnails (3 max, 32×32px, 6px radius, overlapping slightly like a stack) + "· 3 items" in 12px #6B7280.

Bottom row of card: divider line above. "Total" in 13px #6B7280 left, price in 15px bold #D97706 right. If status is COMPLETED: a small "Leave Review" button in #FEF3C7 text #D97706 13px bold, pill shaped, right-aligned.

**Empty state** (if no orders): Centered vertically — a large outlined receipt icon in #E5E7EB (64px), below it "No orders yet" in 18px bold #111827, below that "Your order history will appear here" in 14px #9CA3AF.

**Bottom nav:** "Orders" tab active.

---

## Screen 8 — AI Waiter Chat

**Prompt:**

Design an AI chat screen for a restaurant app called Gasthaus. This is a conversational AI menu recommendation interface.

**Top bar:** #1C1C1E dark background, 56px tall. Left side: a small sparkle/star icon in #D97706 + "AI Waiter" text in 17px bold white. Right side: a refresh/clear icon (outlined, 22px, #9CA3AF) to clear chat history.

**Body background:** #F9F9F7.

**Welcome banner** (shown only when chat is empty): Centered in the screen. A soft amber rounded card (#FFFBEB background, 1px #FDE68A border, 16px padding, 12px radius):
- A 48px sparkle icon in #D97706 at top center.
- "Ask me anything!" in 18px bold #111827.
- "I can help you choose dishes based on your mood, dietary needs, or cravings." in 14px #6B7280 centered.
- Below: 3 suggestion chips in a wrap row: "What's popular?", "I'm vegetarian", "Something spicy". Each: #FFFFFF background, 1px #E5E7EB border, 12px radius, 13px #6B7280 text, 12px horizontal padding, 8px vertical padding.

**Chat messages area** (scrollable, 20px horizontal padding, 16px vertical padding, 8px gap between messages):

User message bubble: Right-aligned. #D97706 background, white text, 16px padding, 16px radius with bottom-right corner 4px (speech bubble shape). Max width 75% of screen. 14px text.

AI message bubble: Left-aligned. #FFFFFF background, 1px #E5E7EB border, 16px padding, 16px radius with bottom-left corner 4px. Max width 85% of screen. 14px #111827 text. Small sparkle icon + "AI Waiter" label in 11px #9CA3AF above each AI bubble.

Typing indicator: AI bubble with three animated dots (#9CA3AF, bouncing).

**Bottom input area** (white background, 1px #E5E7EB top border, 12px vertical padding, 20px horizontal padding, safe-area aware):
- Row: text input field (flex-grow, 44px tall, 10px radius, 1px #E5E7EB border, "Ask about the menu…" placeholder in #9CA3AF) + send button to the right (44px circle, #D97706 background, white paper-plane icon, 8px left margin). Send button disabled/gray when input is empty.

**Bottom nav:** "AI Waiter" tab active.

---

## Screen 9 — Write Review

**Prompt:**

Design a write review bottom sheet for a restaurant app called Gasthaus. It slides up from the bottom, covering about 70% of the screen. Background behind is dimmed.

**Sheet:** White background, 20px top border radius. Drag handle at top center (40×4px, #E5E7EB, 8px from top).

**Content (20px horizontal padding, 20px top padding):**

Title: "Leave a Review" in 20px bold #111827. Subtitle: item name in 14px #6B7280 below.

**Star rating selector:** 5 large stars in a centered row, 36px each, 8px gap. Tappable. Filled star: #D97706. Empty star: #E5E7EB. When tapped, stars fill from left to the tapped index with a subtle scale animation.

Below stars: current rating label in 14px #6B7280, e.g. "Excellent" for 5 stars, "Good" for 4, "Average" for 3, "Poor" for 2, "Terrible" for 1.

**Comment input:** Label "YOUR REVIEW" in 11px bold uppercase #9CA3AF. Multiline text field, 120px tall, 1px #E5E7EB border, 10px radius, 13px #111827 text. Placeholder: "Tell others what you think about this dish…"

Character count: bottom-right of the text field in 11px #9CA3AF, e.g. "0/500".

**Submit button:** Full-width, 52px, #D97706, white "Submit Review" text, 10px radius. Disabled (opacity 0.4) until at least 1 star is selected. 20px top margin.

---

## Screen 10 — Profile

**Prompt:**

Design a profile screen for a mobile restaurant app called Gasthaus.

**Top area:** #1C1C1E dark background. 100px tall. 20px horizontal padding. User avatar: 56px circle, #D97706 background, white initials text 20px bold Inter, centered. To the right of avatar: user's full name in 18px bold white, role in 13px #9CA3AF below ("Customer"). No edit button — read only.

**Body background:** #F9F9F7.

**Stats row** (20px horizontal margin, 16px top margin): A white card (12px radius, 1px #E5E7EB border, 16px padding) with 3 equal columns separated by vertical dividers (#F3F4F6):
- Column 1: number in 20px bold #111827, "Orders" label in 11px #9CA3AF below
- Column 2: number in 20px bold #D97706, "Reviews" label in 11px #9CA3AF below
- Column 3: "4.8★" in 20px bold #111827, "Avg Rating" label in 11px #9CA3AF below

**Account section** (20px horizontal margin, 24px top margin): Section header "ACCOUNT" in 11px bold uppercase #9CA3AF. White card (12px radius, 1px #E5E7EB border):
- Each row: 56px tall, 16px horizontal padding, icon on left (22px outlined, #9CA3AF), label in 15px #111827, chevron right icon on far right (#9CA3AF).
- Rows: "Full Name" / "Email Address" / "Change Password"
- Dividers between rows (#F3F4F6, 1px)

**Support section** (20px margin, 16px top): Section header "SUPPORT" in 11px bold uppercase #9CA3AF. Same card style:
- Rows: "About Gasthaus" / "Terms of Service"

**Danger section** (20px margin, 16px top): No header. White card (12px radius, 1px #E5E7EB border):
- Single row: "Log Out" in 15px #DC2626, logout icon in #DC2626 on left. No chevron.

**Bottom nav:** "Profile" tab active.
