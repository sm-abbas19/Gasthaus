# Design System: High-End Editorial Gastronomy

## 1. Overview & Creative North Star
**Creative North Star: "The Modern Archivist"**

This design system rejects the cluttered, image-heavy tropes of standard restaurant templates. Instead, it adopts the austere, structured elegance of high-end editorial design and the functional clarity of productivity tools. By marrying the "Michelin-starred" culinary philosophy—precision, reduction, and quality—with a "Notion-esque" digital utility, we create an experience that feels both archival and avant-garde.

The system breaks the "template" look through **Rigid Asymmetry**. While most sites rely on centered stacks, this system utilizes split-screen layouts and intentional white space to guide the eye. It is a digital "tasting menu": deliberate, paced, and expensive.

---

## 2. Colors & Surface Logic
The palette is rooted in organic, earthy tones—charcoal, bone, and amber—mimicking the physical materials of a premium dining room (iron, linen, and candlelight).

### The "No-Line" Rule
To maintain an upscale feel, **1px solid borders are strictly prohibited for sectioning.** Boundaries must be defined solely through background shifts. For example, a `surface-container-low` section should sit directly against a `surface` background. The transition in tone provides enough visual information to signal a new context without the "cheapness" of a stroke.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers of fine paper. 
- **Base Layer:** `surface` (#f9f9f7) for the main canvas.
- **Secondary Layer:** `surface-container-low` (#f4f4f2) for secondary content blocks.
- **Interactive Layer:** `surface-container-highest` (#e2e3e1) for subtle hover states or tertiary buttons.

### The "Anti-Digital" Rule
Per the creative direction, **gradients, glassmorphism, and drop shadows are forbidden.** Depth is achieved through "Tonal Layering." If an element needs to feel prominent, do not lift it with a shadow; instead, shift its background color to `surface-container-lowest` (#ffffff) to make it "pop" against the warmer off-white base.

---

## 3. Typography: The Editorial Voice
We use a single typeface, **Inter**, but manipulate weight and tracking to create a sophisticated hierarchy. 

*   **Wordmarks & Display:** Use `display-lg` with `font-weight: 300` and `letter-spacing: 0.15em`. This high tracking mimics luxury branding and should be used sparingly for section headers.
*   **The Utility Mid-Tone:** Titles (`title-md`) use `font-weight: 600` to provide a functional anchor, ensuring the user never feels lost in the minimalism.
*   **The Body:** `body-md` uses `font-weight: 400` with an increased line-height to ensure the menu descriptions feel breathable and legible.

---

## 4. Elevation & Depth: Tonal Layering
Since shadows are removed from the toolkit, we use the **Stacking Principle**.

*   **The Layering Principle:** Place a `surface-container-lowest` card on a `surface-container-low` section. This creates a soft, natural "lift" mimicking a white menu card sitting on a grey linen tablecloth.
*   **The "Ghost Border" Fallback:** If a layout requires a hard boundary (e.g., an input field), use the `outline-variant` (#dbc2b0) at **20% opacity**. It should be felt, not seen.
*   **Asymmetric Alignment:** Utilize the **Spacing Scale** to create "breathing pockets." A hero image should not be centered; it should be offset (e.g., `margin-left: 10 (3.5rem)` and `margin-right: 20 (7rem)`) to create a bespoke, non-templated rhythm.

---

## 5. Components

### Buttons
*   **Primary:** `background: primary` (#8d4b00), `on-primary` (#ffffff) text. **Radius: 6px.** No shadow. Use `font-weight: 600`.
*   **Secondary:** `background: transparent`, `outline: 1px solid primary`. Use for "View Menu" or secondary actions.
*   **States:** On hover, the primary button shifts to `primary-container` (#b15f00). No movement or lift.

### Input Fields
*   **Structure:** Transparent background with a `bottom-border` only, using `outline-variant`. 
*   **Focus State:** The bottom border transitions to `primary` (#8d4b00). Helper text uses `label-sm` in `on-surface-variant`.

### Cards (The "Menu Item")
*   **Rule:** Forbid divider lines.
*   **Layout:** Use a `split-layout`. Image on the left (50%), typography on the right (50%), vertically centered. 
*   **Spacing:** Use `spacing-8` (2.75rem) between cards to signify premium exclusivity.

### Chips (Dietary Tags)
*   **Style:** `surface-container-high` background, `on-surface` text, `font-weight: 600`, uppercase, `label-sm`. These act as "stamps" of information.

---

## 6. Do’s and Don’ts

### Do:
*   **Center with Intent:** Use horizontal and vertical centering for hero statements to create a "Gallery" feel.
*   **Embrace the Grid:** Use the `spacing-24` (8.5rem) for top/bottom padding of sections.
*   **Use Amber Sparingly:** Use `primary` (#8d4b00) only for the most critical actions (e.g., "Book a Table") or to highlight a Michelin star.

### Don’t:
*   **No Rounding:** Never exceed the `lg` (0.5rem / 6px) border radius. Anything more feels "bubbly" and consumer-grade, not premium.
*   **No Standard Grids:** Avoid 3-column or 4-column card rows. Use alternating 2-column split layouts or single-column centered stacks.
*   **No Pure Black:** Never use #000000. Use `on-secondary-fixed` (#1b1b1d) for maximum depth without the "digital" harshness of true black.

---

## 7. Signature Layout Pattern: The Split-Hero
To differentiate from standard sites, the landing experience must be a **50/50 Split**. 
- **Left Pane:** A high-resolution, high-contrast photograph of a single ingredient or a corner of the architecture.
- **Right Pane:** `surface` background, vertically centered `display-md` typography. 

This asymmetry communicates that the brand is confident enough to "waste" space in pursuit of beauty.