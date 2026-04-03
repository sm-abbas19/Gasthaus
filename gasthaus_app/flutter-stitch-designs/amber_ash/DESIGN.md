# Design System Strategy: The Modern Gastronomy Editorial

## 1. Overview & Creative North Star
**Creative North Star: "The Tactile Menu"**
This design system moves away from the sterile, modular grid of standard SaaS apps and instead draws inspiration from high-end physical menu design and boutique hospitality. The goal is to create a digital experience that feels as curated and intentional as a reserved table at a premium bistro. 

We achieve this through **Editorial Asymmetry** and **Tonal Depth**. Instead of boxing content into rigid rows, we use white space as a structural element, allowing typography to breathe and images to bleed across containers. This system prioritizes a "human" touch—warm, inviting, and sophisticated—where the interface disappears to let the culinary photography and typography lead the user journey.

---

## 2. Colors & Surface Logic
The palette is rooted in organic warmth. We move away from pure, cold whites in favor of a "Paper & Ink" philosophy.

*   **Primary Accent (`#D97706`):** This is our "Aged Amber." Use it sparingly for high-intent actions or to highlight a "Chef’s Choice" item. It should feel like a wax seal—authoritative and premium.
*   **The "No-Line" Rule:** While the initial brief mentions borders, our directorial evolution dictates that **structural sectioning must not rely on 1px solid lines.** To achieve a high-end feel, use background shifts. A `surface-container-low` (`#F4F4F2`) section sitting on a `background` (`#F9F9F7`) creates a sophisticated boundary that feels architectural rather than "templated."
*   **Surface Hierarchy:**
    *   **Lowest:** Pure White (`#FFFFFF`) for cards and interactive inputs to create "lift."
    *   **Background:** Warm Off-White (`#F9F9F7`) for the primary canvas.
    *   **High/Highest:** Use these deeper tones (`#E8E8E6` / `#E2E3E1`) for footer areas or "Dark Mode" stylistic interjections to break the scroll rhythm.
*   **Signature Textures:** For primary CTAs, do not use a flat fill. Apply a subtle linear gradient from `primary` (`#8D4B00`) to `primary-container` (`#B15F00`) at a 135-degree angle. This adds a "glow" that mimics light hitting a glass of aged spirit.

---

## 3. Typography
We utilize **Inter** not as a system font, but as a modernist editorial tool.

*   **Display & Headline:** Used for hero messaging. High contrast in size compared to body text is essential to create an "Editorial" hierarchy.
*   **Title-SM (Section Headers):** `13px/700` uppercase with `0.08em` letter-spacing. These are your "Signposts." They should be treated as graphic elements, often paired with ample top-margin (`spacing-8`) to signal a new chapter in the user experience.
*   **Body-MD:** `15px/400`. The workhorse. Ensure a line-height of at least `1.5` to maintain the "bistro menu" readability.
*   **Label-SM:** Use for metadata (e.g., "Gluten-Free," "Spicy"). These should be subtle, using `on-surface-variant` (`#554336`) to avoid distracting from the primary dish names.

---

## 4. Elevation & Depth
In this system, we replace traditional shadows with **Tonal Layering** and **Atmospheric Blurs.**

*   **The Layering Principle:** Depth is "stacked." To highlight a featured seasonal dish, place a `surface-container-lowest` card on a `surface-container-low` background. This creates a "soft lift" that feels like a heavy cardstock menu resting on a linen tablecloth.
*   **The Ghost Border:** Where containment is strictly required (e.g., input fields), use the `outline-variant` token at **20% opacity**. This creates a "Ghost Border" that defines the shape without cutting the eye with high-contrast lines.
*   **Glassmorphism:** For navigation bars or floating "Book a Table" buttons, use a `surface` color at 80% opacity with a `20px` backdrop blur. This allows the vibrant colors of food photography to peek through, keeping the UI integrated with the content.

---

## 5. Components

### Buttons & Inputs
*   **Primary Action:** `52px` height, `10px` radius. Use the signature Amber gradient. Text should be `label-md` bold and centered.
*   **Inputs:** `52px` height. Instead of a heavy border, use a `1px` Ghost Border (`outline-variant` @ 20%). The background should be `surface-container-lowest` (#FFFFFF) to pop against the off-white page.

### Cards (The "Menu Item")
*   **Construction:** `12px` radius. No shadows. Internal padding of `16px` (`spacing-4`). 
*   **Evolution:** For "Premium" menu items, remove the border entirely and use a subtle `surface-container-low` background fill to differentiate from the main list.

### Chips & Tags
*   **Styling:** Use `full` (pill) radius. Background should be `surface-variant` with `on-surface-variant` text. These should feel like small stones—smooth and unobtrusive.

### Interactive Lists
*   **Rule:** Forbid the use of horizontal divider lines. Use `spacing-6` (1.5rem) of vertical whitespace to separate list items. If separation is visually impossible without a line, use a `1px` line that fades out at the edges (a gradient stroke) to maintain the "Editorial" feel.

---

## 6. Do’s and Don’ts

### Do
*   **Do** use asymmetrical margins. For example, a heading might have a `20px` left margin while the body text below it is indented to `40px`.
*   **Do** prioritize high-quality photography. The UI is a frame for the food.
*   **Do** use the "Warm Amber" for interactive states (hover/active) to provide a tactile "glow" response.

### Don’t
*   **Don’t** use standard 1px `#E5E7EB` borders for every container. It makes the app look like a generic dashboard. Refer to the "No-Line" rule.
*   **Don’t** use pure black `#000000`. Use the `on-surface` (`#1A1C1B`) for text to maintain the organic, high-end feel.
*   **Don’t** crowd the screen. If a screen feels "full," increase the spacing tokens. Premium brands "waste" space intentionally.

---

## 7. Spacing Scale Reference
*   **Screen Padding:** `spacing-5` (20px) horizontal.
*   **Component Gap:** `spacing-4` (16px) for internal card elements.
*   **Section Gap:** `spacing-10` (40px) to separate major content groups.