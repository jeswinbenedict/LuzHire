---
version: alpha
name: LuzHire
description: LuzHire's design language. "Luz" means light, so the brand is built around a warm sunrise amber used sparingly against near-black ink and clean white or deep-graphite surfaces. Public and candidate screens (the "Spotlight" zone) borrow the friendly, high-energy rhythm of Jobright — tinted section bands, bold display headings, pill CTAs, generous rounded cards. Employer and admin screens (the "Workspace" zone) borrow Linear's dense, calm, hairline-bordered product craft — small radii, a surface ladder instead of shadows, one accent. Both zones ship light and dark themes from the same token set.

colors:
  # ---------- brand (both themes) ----------
  primary: "#FFB224"           # Luz amber: signature pill, brand mark, highlights, dark-theme links/focus
  primary-hover: "#FFC453"
  primary-pressed: "#E89A0C"
  on-primary: "#14110F"        # text/icons on amber — never white
  primary-strong: "#A84D07"    # amber that passes AA on light surfaces: links, focus ring, active nav (light theme)

  # ---------- light theme ----------
  ink: "#14110F"               # headings, body, black pills
  ink-muted: "#3D4148"         # secondary body
  muted: "#5F646B"             # captions, meta, placeholders
  disabled: "#9A9EA6"          # disabled text only (not for information)
  on-dark: "#FFFFFF"
  canvas: "#FFFFFF"
  canvas-tint: "#FFF7E6"       # pale amber bands (hero, features, CTA) — Spotlight only
  surface-soft: "#F4F4F2"      # inputs, inset panels
  surface-1: "#FFFFFF"         # Workspace cards on canvas-sub
  canvas-sub: "#F7F7F5"        # Workspace page background (light)
  surface-2: "#F1F1EE"         # hover, selected row
  hairline: "#E6E4DF"
  hairline-strong: "#D3D0C9"

  # ---------- dark theme ----------
  dark-canvas: "#0B0C0E"
  dark-surface-1: "#121316"
  dark-surface-2: "#17191C"
  dark-surface-3: "#1C1E22"
  dark-canvas-tint: "#1A160D"  # dark counterpart of the amber band
  dark-hairline: "#26282D"
  dark-hairline-strong: "#34373D"
  dark-ink: "#F5F5F3"
  dark-ink-muted: "#C9CCD1"
  dark-muted: "#9A9EA6"
  dark-disabled: "#63676E"

  # ---------- semantic ----------
  success: "#15803D"
  dark-success: "#3DD68C"
  warning: "#C2410C"           # orange, kept distinct from brand amber
  dark-warning: "#FB923C"
  danger: "#B91C1C"
  dark-danger: "#F87171"
  info: "#1D4ED8"
  dark-info: "#93B4FF"
  scrim: "#000000"             # modal overlay at 48% (light) / 64% (dark)

  # ---------- status chips (bg / fg) ----------
  chip-neutral-bg: "#F1F2F4"
  chip-neutral-fg: "#4B5058"
  chip-blue-bg: "#EFF4FF"
  chip-blue-fg: "#1D4ED8"
  chip-violet-bg: "#F3EEFF"
  chip-violet-fg: "#6D28D9"
  chip-amber-bg: "#FFF4DB"
  chip-amber-fg: "#92400E"
  chip-green-bg: "#EAF7EE"
  chip-green-fg: "#166534"
  chip-red-bg: "#FDECEC"
  chip-red-fg: "#B91C1C"
  dark-chip-neutral-bg: "#202227"
  dark-chip-neutral-fg: "#B9BDC4"
  dark-chip-blue-bg: "#1A2236"
  dark-chip-blue-fg: "#93B4FF"
  dark-chip-violet-bg: "#241C38"
  dark-chip-violet-fg: "#C4B0FF"
  dark-chip-amber-bg: "#332611"
  dark-chip-amber-fg: "#FFC66B"
  dark-chip-green-bg: "#15291E"
  dark-chip-green-fg: "#7EE2A8"
  dark-chip-red-bg: "#331A1A"
  dark-chip-red-fg: "#FCA5A5"

typography:
  # Spotlight display (public + candidate marketing surfaces)
  display:
    fontFamily: Plus Jakarta Sans
    fontSize: 64px
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: -1.5px
  heading-1:
    fontFamily: Plus Jakarta Sans
    fontSize: 48px
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: -1px
  heading-2:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: -0.5px
  heading-3:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: -0.3px
  heading-4:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: -0.2px
  # Workspace headings (employer + admin; also in-app candidate pages)
  ws-title:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: -0.4px
  ws-section:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: -0.2px
  ws-card-title:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: 600
    lineHeight: 1.35
    letterSpacing: -0.1px
  # Shared text
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 400
    lineHeight: 1.6
    letterSpacing: 0
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.55
    letterSpacing: 0
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0
  label:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: 0
  button:
    fontFamily: Inter
    fontSize: 15px
    fontWeight: 600
    lineHeight: 1
    letterSpacing: 0
  button-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: 600
    lineHeight: 1
    letterSpacing: 0
  caption:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: 0
  eyebrow:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: 0.6px
  mono:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0

rounded:
  none: 0px
  xs: 4px          # Workspace chips, table rows, kbd
  sm: 6px          # Workspace inline tags
  md: 8px          # Workspace buttons + inputs
  lg: 12px         # Workspace cards, Spotlight inputs
  xl: 16px         # Spotlight job cards, modals
  xxl: 24px        # Spotlight feature cards, bottom sheets
  hero: 32px       # Spotlight hero/CTA panels
  pill: 9999px     # Spotlight CTAs, filter chips, status pills
  full: 9999px     # avatars

spacing:
  xxs: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  xxl: 48px
  section: 96px
  section-mobile: 56px

components:
  # ----- Spotlight zone -----
  nav-bar:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    height: 64px
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-dark}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
  button-signature:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    border: "1px solid {colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
  button-secondary:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    border: "1px solid {colors.hairline-strong}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
  search-bar:
    backgroundColor: "{colors.canvas}"
    border: "1px solid {colors.hairline}"
    rounded: "{rounded.pill}"
    height: 56px
    shadow: "0 8px 24px rgba(20,17,15,0.08)"
  filter-chip:
    backgroundColor: "{colors.surface-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "8px 14px"
  filter-chip-selected:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-dark}"
    rounded: "{rounded.pill}"
  job-card:
    backgroundColor: "{colors.canvas}"
    border: "1px solid {colors.hairline}"
    rounded: "{rounded.xl}"
    padding: "{spacing.lg}"
  feature-card:
    backgroundColor: "{colors.canvas}"
    rounded: "{rounded.xxl}"
    padding: "{spacing.xl}"
    shadow: "0 12px 32px rgba(20,17,15,0.06)"
  band-tint:
    backgroundColor: "{colors.canvas-tint}"
    padding: "{spacing.section} 0"
  band-dark:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-dark}"
    padding: "{spacing.section} 0"
  match-ring:
    size: 56px
    stroke: 5px
    trackColor: "{colors.hairline}"
    valueColor: "{colors.primary}"
  # ----- Workspace zone -----
  ws-sidebar:
    backgroundColor: "{colors.canvas-sub}"
    width: 240px
    itemHeight: 32px
    itemRounded: "{rounded.sm}"
    itemActiveBackground: "{colors.surface-2}"
  ws-topbar:
    backgroundColor: "{colors.canvas}"
    borderBottom: "1px solid {colors.hairline}"
    height: 52px
  ws-button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-dark}"
    typography: "{typography.button-sm}"
    rounded: "{rounded.md}"
    padding: "8px 14px"
  ws-button-accent:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button-sm}"
    rounded: "{rounded.md}"
    padding: "8px 14px"
  ws-button-secondary:
    backgroundColor: "{colors.surface-1}"
    textColor: "{colors.ink}"
    border: "1px solid {colors.hairline}"
    typography: "{typography.button-sm}"
    rounded: "{rounded.md}"
    padding: "8px 14px"
  ws-input:
    backgroundColor: "{colors.surface-1}"
    border: "1px solid {colors.hairline}"
    focusBorder: "1px solid {colors.primary-strong}"
    rounded: "{rounded.md}"
    padding: "8px 12px"
    height: 36px
  ws-card:
    backgroundColor: "{colors.surface-1}"
    border: "1px solid {colors.hairline}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"
  ws-table-row:
    height: 44px
    border: "1px solid {colors.hairline}"
    hoverBackground: "{colors.surface-2}"
    rounded: "{rounded.xs}"
  ws-kanban-column:
    backgroundColor: "{colors.canvas-sub}"
    width: 288px
    rounded: "{rounded.lg}"
    padding: "{spacing.xs}"
  ws-kanban-card:
    backgroundColor: "{colors.surface-1}"
    border: "1px solid {colors.hairline}"
    rounded: "{rounded.md}"
    padding: "{spacing.sm}"
  ws-stat-tile:
    backgroundColor: "{colors.surface-1}"
    border: "1px solid {colors.hairline}"
    rounded: "{rounded.lg}"
    padding: "{spacing.md}"
  command-menu:
    backgroundColor: "{colors.surface-1}"
    border: "1px solid {colors.hairline-strong}"
    rounded: "{rounded.xl}"
    width: 640px
  # ----- shared -----
  status-chip:
    typography: "{typography.caption}"
    rounded: "{rounded.pill}"
    padding: "2px 8px"
  modal:
    backgroundColor: "{colors.surface-1}"
    rounded: "{rounded.xl}"
    padding: "{spacing.lg}"
  bottom-sheet:
    backgroundColor: "{colors.surface-1}"
    rounded: "{rounded.xxl} {rounded.xxl} 0 0"
  toast:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-dark}"
    rounded: "{rounded.lg}"
  focus-ring:
    outline: "2px solid {colors.primary-strong}"
    outlineDark: "2px solid {colors.primary}"
    offset: 2px
---

# LuzHire Design System

## 1. Overview

LuzHire has two zones that share one token set:

| Zone | Screens | Reference | Personality |
|---|---|---|---|
| **Spotlight** | Home, job search, job detail, companies, career news, auth, candidate dashboard / profile / applications | Jobright | Warm, energetic, optimistic. Big bold headings, amber-tinted bands, pill CTAs, rounded cards, generous whitespace. |
| **Workspace** | Employer dashboard, job editor, pipeline kanban, interviews, analytics, team; all admin screens | Linear | Calm, dense, precise. Small radii, hairlines, surface ladder, one accent, keyboard-first. |

Both zones support **light and dark** themes. Default follows the OS setting; the user can override (System / Light / Dark) in settings, and the choice syncs to their profile.

The brand is *light*: a single sunrise amber (`primary #FFB224`) that appears where something deserves attention — the brand mark, the one signature CTA per screen, match scores, the "Offer" stage, the active nav indicator in dark mode. Everything else is ink and neutral surfaces.

## 2. Colors

### Brand
- **Luz amber `#FFB224`** — fills and highlights only. Text on amber is always `on-primary #14110F` (10.4:1). Never put white text on amber.
- **Amber strong `#A84D07`** — the amber used for *text and focus rings on light surfaces* (5.6:1 on white). Light-theme links, active tab underline, focus ring.
- In **dark** theme, plain `primary` is used for links and focus rings (10.9:1 on `dark-canvas`).

### Neutrals
Light: `canvas #FFFFFF` → `canvas-sub #F7F7F5` (Workspace page) → `surface-soft #F4F4F2` → `surface-2 #F1F1EE`. Borders `hairline #E6E4DF`, `hairline-strong #D3D0C9`. Text `ink #14110F`, `ink-muted #3D4148`, `muted #5F646B` (≥ 5.4:1 on all light surfaces).

Dark (Linear-style ladder; never skip a level): `dark-canvas #0B0C0E` → `dark-surface-1 #121316` → `dark-surface-2 #17191C` → `dark-surface-3 #1C1E22`. Borders `dark-hairline #26282D`, `dark-hairline-strong #34373D`. Text `dark-ink #F5F5F3`, `dark-ink-muted #C9CCD1`, `dark-muted #9A9EA6`.

`disabled` / `dark-disabled` are for disabled controls only — never for information a user must read.

### Theme mapping
Every light token has a `dark-` counterpart. When building a component, reference the light token name; the theme layer swaps it:

| Light | Dark |
|---|---|
| canvas | dark-canvas |
| canvas-sub | dark-canvas |
| surface-1 | dark-surface-1 |
| surface-soft, surface-2 | dark-surface-2 |
| canvas-tint | dark-canvas-tint |
| hairline / hairline-strong | dark-hairline / dark-hairline-strong |
| ink / ink-muted / muted | dark-ink / dark-ink-muted / dark-muted |
| primary-strong (links, focus) | primary |
| button-primary `ink` fill + white text | `dark-ink` fill + `dark-canvas` text |
| band-dark `ink` | `dark-surface-2` with `dark-hairline` top/bottom border |
| chip-*-bg / chip-*-fg | dark-chip-*-bg / dark-chip-*-fg |
| success / warning / danger / info | dark-success / dark-warning / dark-danger / dark-info |

### Semantic
`success` green, `warning` **orange** (deliberately not amber, so warnings never read as brand), `danger` red, `info` blue. Always pair color with an icon or text — never color alone.

### Application stage chips
| Stage | Chip |
|---|---|
| Applied | neutral |
| Under review | blue |
| Shortlisted | violet |
| Assessment, Technical interview, HR interview | blue (with stage icon) |
| Final review | violet |
| Offer issued | amber |
| Hired | green |
| Rejected | red |
| Withdrawn | neutral, strikethrough label |

Job status chips: Draft neutral · Pending review amber · Published green · Closed neutral · Archived neutral · Rejected red.
Company verification: Verified = green chip with check icon; Pending = amber; Unverified = no chip.

## 3. Typography

- **Plus Jakarta Sans** (700–800) — Spotlight display and headings only. Tight negative tracking at large sizes.
- **Inter** (400 / 500 / 600) — all UI, body, Workspace headings. Workspace never goes above 600.
- **JetBrains Mono** (400) — IDs, audit log payloads, keyboard shortcuts.

All three are open-licensed (OFL) and are **bundled as assets** in the Flutter app — no runtime font fetching.

Mobile scaling (< 600 px): display 40 px, heading-1 34 px, heading-2 28 px, heading-3 22 px, heading-4 19 px. Body sizes do not shrink below 14 px. Respect the OS text-scale setting up to 200 % without clipping.

## 4. Layout

- 4 px base grid; spacing tokens 4 / 8 / 12 / 16 / 24 / 32 / 48 / 96.
- **Spotlight:** centered content column, max 1200 px; sections separated by 96 px (56 px on mobile), alternating `canvas` and `canvas-tint` bands; one `band-dark` per page at most (e.g. live job ticker or testimonial).
- **Workspace:** full-width app shell — 240 px sidebar + 52 px top bar + content (max 1440 px). 24 px page padding, 16 px gaps between cards, 12 px inside dense cards.
- Card grids: 3-up ≥ 1024 px, 2-up 600–1023, 1-up < 600.

## 5. Elevation & Depth

- **Spotlight:** depth comes from band contrast and soft shadows on floating cards only (`0 12px 32px rgba(20,17,15,0.06)`); the hero search bar gets `0 8px 24px rgba(20,17,15,0.08)`. Dark theme drops shadows and uses `dark-surface-1` + hairline instead.
- **Workspace:** no shadows. Lift = next surface step + 1 px hairline. Menus/popovers use `surface-1` + `hairline-strong` (+ a 1 px top highlight `rgba(255,255,255,0.04)` in dark).
- Modals: `scrim` at 48 % (light) / 64 % (dark).

## 6. Shapes

Spotlight is round: pills for CTAs, chips and the search bar; 16 px job cards; 24 px feature cards; 32 px hero/CTA panels.
Workspace is crisp: 8 px buttons and inputs; 12 px cards; 4–6 px chips, rows and tags.
Avatars and company logos: avatars circular; company logos 12 px rounded squares on a `surface-soft` tile.

## 7. Components

### Spotlight
- **Top nav** (64 px): logo left; Jobs · Companies · News · For employers; right: theme toggle, `Sign in` (secondary pill), `Get started` (primary pill). < 768 px: hamburger + `Get started` stays visible.
- **Hero search bar**: pill, 56 px, two fields (role/keyword | location) + amber signature button "Search". On mobile the fields stack inside a 24 px-radius card.
- **Filter chips**: horizontally scrollable row under the search bar; "All filters" opens a bottom sheet (mobile) or side panel (desktop). Results always render before the filter panel on mobile.
- **Job card**: logo tile, title (heading-4 on desktop / ws-card-title on mobile), company + verified chip, 3 meta chips (location · type · salary with period), 2-line summary, posted-time caption, save (bookmark) icon button, and a **match ring** when the candidate has a profile. External jobs show a "via <source>" caption and an external-link icon on Apply.
- **Job detail**: two-pane on ≥ 1024 px (sticky apply panel on the right); single column with a sticky bottom Apply bar on mobile.
- **Candidate dashboard**: greeting + profile-completion ring; cards for Applications (stage chips), Upcoming interviews, Saved jobs, Recommended jobs.
- **Empty states**: one line of copy, one action, a simple line illustration in `muted` with a single amber accent.

### Workspace
- **Sidebar**: 32 px items, 16 px icons, `label` text; active item = `surface-2` fill + 2 px amber left indicator. Collapsible to a 56 px icon rail; becomes a drawer < 1024 px.
- **Tables** (applicants, users, audit log): 44 px rows, hairline dividers, sticky header, sortable columns, row hover `surface-2`, bulk-select checkbox column, mono for IDs.
- **Pipeline kanban**: one column per stage (288 px), column header = stage chip + count; cards show avatar, name, current title, match score, applied-ago, next interview. Drag-and-drop with keyboard alternative (focus card → `M` → choose stage). Horizontal scroll on tablet; on mobile, a stage selector replaces columns.
- **Stat tiles**: label (caption, muted), value (ws-title), delta chip. Only real numbers — show "—" when there is no data.
- **Command menu** (`Ctrl/⌘ K`): jump to job, candidate, company, or action.
- **Forms**: labels above fields, helper text in `muted`, errors in `danger` with icon below the field; job editor is a two-column form with a live preview of the public job card.

### Shared
- **Status chips** — see §2.
- **Toasts** — bottom-center on mobile, bottom-right on desktop; ink background; 4 s; include Undo for destructive actions.
- **Notifications panel** — right sheet; unread dot in amber; grouped by Today / Earlier.
- **Skeletons** — `surface-2` blocks with a subtle shimmer; never show spinners for list loads.
- **Focus ring** — 2 px `primary-strong` (light) / `primary` (dark), 2 px offset, on every interactive element.

## 8. Motion

Durations 120 ms (hover, press), 200 ms (chips, toggles), 280 ms (sheets, dialogs, page transitions). Easing: standard `cubic-bezier(0.2, 0, 0, 1)`. Realtime inserts (new applicant, new notification) fade + slide 8 px. Respect reduced-motion: replace movement with opacity only.

## 9. Responsive Behavior

| Name | Width | Behavior |
|---|---|---|
| compact | < 600 | bottom navigation (candidate), drawer (workspace), single column, bottom sheets for filters and actions |
| medium | 600 – 1023 | navigation rail, 2-up grids, kanban scrolls horizontally |
| expanded | 1024 – 1439 | full sidebar, two-pane job search, 3-up grids |
| large | ≥ 1440 | content capped (1200 Spotlight / 1440 Workspace), extra space becomes margin |

Touch targets ≥ 48 × 48 dp on touch devices; Workspace controls may be 36 px tall on pointer devices only.

## 10. Accessibility

- Every text pair in this file meets WCAG 2.1 AA (≥ 4.5:1; large text ≥ 3:1); focus rings ≥ 3:1.
- Do not convey stage, status or errors by color alone.
- Every icon-only button has a tooltip and a `Semantics` label.
- Logical focus order; all Workspace actions reachable by keyboard; Esc closes overlays.

## 11. Flutter Implementation Notes

- Tokens live in `app/lib/core/theme/tokens.dart`, generated from this file's front matter; `AppTheme.light()` / `AppTheme.dark()` build Material 3 `ThemeData` and expose extra tokens through a `ThemeExtension<LuzTokens>` (surfaces ladder, chips, zones).
- `ColorScheme` mapping: `primary` → primary, `onPrimary` → on-primary, `surface` → canvas, `surfaceContainerLow/…/Highest` → surface ladder, `outline` → hairline-strong, `outlineVariant` → hairline, `error` → danger.
- A `Zone` inherited widget (`spotlight` | `workspace`) switches component defaults (radii, densities, button shapes) so the same `LuzButton`, `LuzCard`, `LuzChip` widgets render correctly in both zones.
- `VisualDensity.compact` in Workspace on pointer devices; `standard` elsewhere.

## 12. Prompt Guide (for Stitch and coding agents)

When generating a screen, state the **zone**, the **theme(s)**, and the **breakpoint**:
- *Spotlight example:* "LuzHire job search page, Spotlight zone, light theme, desktop 1280 px: white nav, amber-tint hero band with pill search bar and amber Search button, filter chip row, 2-column layout with job cards (16 px radius, hairline border, match ring), right-hand job preview pane. Use DESIGN.md tokens only."
- *Workspace example:* "LuzHire employer pipeline, Workspace zone, dark theme, desktop 1440 px: 240 px sidebar with amber active indicator, 52 px top bar, kanban with one column per stage using stage chips, compact cards with avatar, name, match score. No shadows; surface ladder + hairlines."
- Always generate the light **and** dark variant, and a 390 px mobile variant.
- Work one component at a time by its `components:` name; add variants as new entries.
- Run `npx @google/design.md lint DESIGN.md` after editing this file.

## 13. Do's and Don'ts

**Do**
- Keep amber scarce: one signature amber CTA per screen.
- Use ink (black) pills as the default primary CTA in Spotlight.
- Use the surface ladder and hairlines for depth in Workspace.
- Show real data or an honest empty state.
- Give every external job its source and an external-link icon.

**Don't**
- Put white text on amber, or use amber for warnings.
- Use amber as a full section background (only the pale `canvas-tint`).
- Add a second brand accent color.
- Use pill buttons or big shadows inside Workspace.
- Show invented metrics, placeholder company facts, or decorative "AI" percentages.
- Copy Jobright's mint or Linear's lavender — they are references for rhythm and density, not brand.

## 14. Known Gaps

- Illustration style (empty states, onboarding) still to be produced in Stitch.
- Chart palette for analytics: to be defined (start from the chip hue families, ordered neutral → blue → violet → amber → green).
- Email template styling (transactional emails) not yet specified.
