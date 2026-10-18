---
version: alpha
name: LuzHire
description: LuzHire's design language is accessible neumorphism. Every element is moulded from one soft, warm "porcelain" surface (graphite in dark mode). Raised elements catch light from the top-left and cast a soft shade to the bottom-right; pressed or selected elements sink into the surface. Familiar real-world metaphors (bookmark ribbons, paper-clip attachments, calendar pages, paper cards, physical toggles) make actions obvious at a glance. "Luz" means light, so the single brand accent is a warm sunrise orange (the logo dot), used sparingly. Public and candidate screens (the "Spotlight" zone) borrow Jobright's friendly rhythm with generous, deeply moulded pills and cards. Employer and admin screens (the "Workspace" zone) borrow Linear's density and calm, with shallower relief. Both ship light and dark themes. Shadows never carry meaning on their own — text keeps full AA contrast, inputs keep a visible outline, and focus and selection always add orange.

colors:
  # ---------- brand (both themes) ----------
  primary: "#FE8022"           # Luz orange (logo dot): signature pill, brand mark, highlights, dark-theme links/focus
  primary-hover: "#FF9A4D"
  primary-pressed: "#E86D12"
  on-primary: "#14110F"        # text/icons on orange, never white
  primary-strong: "#9A3F0A"    # orange that passes AA on light surfaces: links, focus ring, active indicators

  # ---------- light theme (porcelain) ----------
  base: "#EEECE7"              # THE surface: page and every raised element share it
  sunken: "#E4E1DA"            # inset wells: inputs, pressed buttons, selected chips, tracks
  highlight: "#FFFFFF"         # top-left light shadow
  shade: "#CBC5BA"             # bottom-right dark shadow
  base-tint: "#F7E6D8"         # orange-tinted band (Spotlight hero / CTA), still moulded
  ink: "#14110F"
  ink-muted: "#3D4148"
  muted: "#5A5F66"
  disabled: "#9A9EA6"          # disabled text only
  on-dark: "#FFFFFF"
  outline: "#85817A"           # 1px outline on inputs and checkboxes (>= 3:1 vs base)
  hairline: "#DAD6CE"          # dividers inside a raised panel (decorative)

  # ---------- dark theme (graphite) ----------
  dark-base: "#1D1F23"
  dark-sunken: "#16171A"
  dark-highlight: "#2A2D33"
  dark-shade: "#0E0F11"
  dark-base-tint: "#2A1F17"
  dark-ink: "#F2F2EF"
  dark-ink-muted: "#C9CCD1"
  dark-muted: "#9EA2AA"
  dark-disabled: "#63676E"
  dark-outline: "#6E737B"
  dark-hairline: "#2B2E34"

  # ---------- semantic ----------
  success: "#15803D"
  dark-success: "#3DD68C"
  warning: "#854D0E"           # dark yellow, kept distinct from the brand orange
  dark-warning: "#FACC15"
  danger: "#B91C1C"
  dark-danger: "#F87171"
  info: "#1D4ED8"
  dark-info: "#93B4FF"
  scrim: "#14110F"             # modal overlay at 40% (light) / 64% (dark)

  # ---------- status chips (inset wells: bg / fg) ----------
  chip-neutral-bg: "#E4E1DA"
  chip-neutral-fg: "#4B5058"
  chip-blue-bg: "#E6EBF7"
  chip-blue-fg: "#1D4ED8"
  chip-violet-bg: "#ECE5F7"
  chip-violet-fg: "#6D28D9"
  chip-orange-bg: "#FBE4D3"
  chip-orange-fg: "#9A3412"
  chip-green-bg: "#E3F1E6"
  chip-green-fg: "#166534"
  chip-red-bg: "#F6E3E1"
  chip-red-fg: "#B91C1C"
  dark-chip-neutral-bg: "#202227"
  dark-chip-neutral-fg: "#B9BDC4"
  dark-chip-blue-bg: "#1A2236"
  dark-chip-blue-fg: "#93B4FF"
  dark-chip-violet-bg: "#241C38"
  dark-chip-violet-fg: "#C4B0FF"
  dark-chip-orange-bg: "#3A2215"
  dark-chip-orange-fg: "#FFB088"
  dark-chip-green-bg: "#15291E"
  dark-chip-green-fg: "#7EE2A8"
  dark-chip-red-bg: "#331A1A"
  dark-chip-red-fg: "#FCA5A5"

elevation:
  # Each raised level = two shadows: highlight (top-left, negative offset) + shade (bottom-right).
  # Inset levels use the same pair inside the element. Dark theme swaps in dark-highlight / dark-shade.
  flat: none
  raised-xs: "-2px -2px 4px {colors.highlight}, 2px 2px 4px {colors.shade}"
  raised-sm: "-4px -4px 8px {colors.highlight}, 4px 4px 8px {colors.shade}"
  raised-md: "-8px -8px 16px {colors.highlight}, 8px 8px 16px {colors.shade}"
  raised-lg: "-12px -12px 24px {colors.highlight}, 12px 12px 24px {colors.shade}"
  inset-sm: "inset 2px 2px 4px {colors.shade}, inset -2px -2px 4px {colors.highlight}"
  inset-md: "inset 4px 4px 8px {colors.shade}, inset -4px -4px 8px {colors.highlight}"
  glow-primary: "0 6px 16px rgba(254,128,34,0.35)"

typography:
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
  xs: 6px
  sm: 10px         # Workspace buttons, inputs, chips
  md: 14px         # Workspace cards, kanban cards
  lg: 18px         # Spotlight job cards, inputs
  xl: 24px         # Spotlight feature cards, modals
  xxl: 32px        # hero panels, bottom sheets
  pill: 9999px
  full: 9999px

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
    backgroundColor: "{colors.base}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    height: 64px
    elevation: "{elevation.raised-xs}"
  button-primary:
    backgroundColor: "{colors.base}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
    elevation: "{elevation.raised-sm}"
    pressedElevation: "{elevation.inset-sm}"
  button-signature:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button}"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
    elevation: "{elevation.glow-primary}"
    pressedBackground: "{colors.primary-pressed}"
  icon-button:
    backgroundColor: "{colors.base}"
    textColor: "{colors.ink-muted}"
    rounded: "{rounded.full}"
    size: 44px
    elevation: "{elevation.raised-xs}"
    pressedElevation: "{elevation.inset-sm}"
  search-bar:
    backgroundColor: "{colors.sunken}"
    border: "1px solid {colors.outline}"
    rounded: "{rounded.pill}"
    height: 56px
    elevation: "{elevation.inset-md}"
  text-input:
    backgroundColor: "{colors.sunken}"
    border: "1px solid {colors.outline}"
    rounded: "{rounded.lg}"
    padding: "14px 16px"
    elevation: "{elevation.inset-sm}"
  filter-chip:
    backgroundColor: "{colors.base}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    padding: "8px 14px"
    elevation: "{elevation.raised-xs}"
  filter-chip-selected:
    backgroundColor: "{colors.sunken}"
    textColor: "{colors.ink}"
    indicator: "{colors.primary-strong}"
    rounded: "{rounded.pill}"
    elevation: "{elevation.inset-sm}"
  job-card:
    backgroundColor: "{colors.base}"
    rounded: "{rounded.lg}"
    padding: "{spacing.lg}"
    elevation: "{elevation.raised-md}"
  feature-card:
    backgroundColor: "{colors.base}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xl}"
    elevation: "{elevation.raised-lg}"
  band-tint:
    backgroundColor: "{colors.base-tint}"
    padding: "{spacing.section} 0"
  match-dial:
    size: 56px
    track: "{colors.sunken}"
    trackElevation: "{elevation.inset-sm}"
    valueColor: "{colors.primary}"
  toggle:
    track: "{colors.sunken}"
    trackElevation: "{elevation.inset-sm}"
    trackOn: "{colors.primary}"
    knob: "{colors.base}"
    knobElevation: "{elevation.raised-xs}"
    width: 52px
    height: 30px
  # ----- Workspace zone -----
  ws-sidebar:
    backgroundColor: "{colors.base}"
    width: 240px
    itemHeight: 36px
    itemRounded: "{rounded.sm}"
    itemActiveElevation: "{elevation.inset-sm}"
    itemActiveIndicator: "{colors.primary-strong}"
  ws-topbar:
    backgroundColor: "{colors.base}"
    height: 56px
    elevation: "{elevation.raised-xs}"
  ws-button:
    backgroundColor: "{colors.base}"
    textColor: "{colors.ink}"
    typography: "{typography.button-sm}"
    rounded: "{rounded.sm}"
    padding: "8px 14px"
    elevation: "{elevation.raised-xs}"
    pressedElevation: "{elevation.inset-sm}"
  ws-button-accent:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.button-sm}"
    rounded: "{rounded.sm}"
    padding: "8px 14px"
    elevation: "{elevation.raised-xs}"
  ws-input:
    backgroundColor: "{colors.sunken}"
    border: "1px solid {colors.outline}"
    rounded: "{rounded.sm}"
    padding: "8px 12px"
    height: 38px
    elevation: "{elevation.inset-sm}"
  ws-panel:
    backgroundColor: "{colors.base}"
    rounded: "{rounded.md}"
    padding: "{spacing.lg}"
    elevation: "{elevation.raised-sm}"
  ws-table-row:
    height: 44px
    divider: "1px solid {colors.hairline}"
    hoverBackground: "{colors.sunken}"
    elevation: "{elevation.flat}"
  ws-kanban-column:
    backgroundColor: "{colors.sunken}"
    width: 288px
    rounded: "{rounded.md}"
    padding: "{spacing.xs}"
    elevation: "{elevation.inset-sm}"
  ws-kanban-card:
    backgroundColor: "{colors.base}"
    rounded: "{rounded.sm}"
    padding: "{spacing.sm}"
    elevation: "{elevation.raised-xs}"
    dragElevation: "{elevation.raised-md}"
  ws-stat-tile:
    backgroundColor: "{colors.base}"
    rounded: "{rounded.md}"
    padding: "{spacing.md}"
    elevation: "{elevation.raised-sm}"
  command-menu:
    backgroundColor: "{colors.base}"
    rounded: "{rounded.xl}"
    width: 640px
    elevation: "{elevation.raised-lg}"
  # ----- shared -----
  status-chip:
    typography: "{typography.caption}"
    rounded: "{rounded.pill}"
    padding: "3px 10px"
    elevation: "{elevation.inset-sm}"
  modal:
    backgroundColor: "{colors.base}"
    rounded: "{rounded.xl}"
    padding: "{spacing.lg}"
    elevation: "{elevation.raised-lg}"
  bottom-sheet:
    backgroundColor: "{colors.base}"
    rounded: "{rounded.xxl} {rounded.xxl} 0 0"
    elevation: "{elevation.raised-lg}"
  toast:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.on-dark}"
    rounded: "{rounded.md}"
  focus-ring:
    outline: "2px solid {colors.primary-strong}"
    outlineDark: "2px solid {colors.primary}"
    offset: 3px
---

# LuzHire Design System — Accessible Neumorphism

## 1. Overview

LuzHire looks like it was **moulded from a single soft material**. The page and every card, button and chip share one surface colour. Elements are distinguished by *relief*: raised items catch light from the top-left and cast a soft shade bottom-right; pressed, selected and input elements *sink* into the surface. A few honest real-world metaphors (skeuomorphism) make actions instantly understandable.

Two zones share one token set:

| Zone | Screens | Reference | Relief |
|---|---|---|---|
| **Spotlight** | Home, job search, job detail, companies, career news, auth, candidate dashboard / profile / applications | Jobright rhythm | Deep and generous: `raised-md`/`raised-lg` cards, pill buttons, big radii |
| **Workspace** | Employer dashboard, job editor, pipeline kanban, interviews, analytics, team; all admin screens | Linear density | Shallow: `raised-xs`/`raised-sm`, 10–14 px radii, tables flat inside one raised panel |

Both zones support **light (porcelain) and dark (graphite)** themes. Default follows the OS; the user can override in settings.

The brand is *light*: a single sunrise orange (the logo dot) (`primary #FE8022`) for the brand mark, the one signature CTA per screen, match dials, active indicators, toggles in the "on" position, and the "Offer" stage. Everything else is moulded neutral.

## 1a. Logo

The official logo is `brand/luzhire-logo-official.png`. It is a near-black rounded tile holding a white **L** and an orange dot, plus the **LuzHire** wordmark. The app uses a vector rebuild of it (`brand/luzhire-mark.svg`, `LuzLogo` / `LuzLogoMark` in Flutter), fitted to the official artwork with under 1 % pixel difference.

| Element | Value |
|---|---|
| Tile | `#131314`, 264-unit grid, corner radius 64 |
| Letter | `#FFFFFF` |
| Dot | `#FE8022`, which is also the brand `primary` |
| Wordmark | Inter 500, font size 0.75 × mark height, gap 0.26 × mark height, ink in light theme and reversed ink in dark |

Rules
- Never recolour, stretch, rotate, outline, emboss or add neumorphic relief to the mark. The logo stays flat on every surface.
- Keep clear space of at least ¼ of the mark height on all sides.
- In dark theme the tile gets a 1 px `rgba(255,255,255,.12)` hairline so it stays defined on graphite. Nothing else changes.
- Minimum sizes: mark 16 px (favicon), full logo with wordmark 24 px mark height.
- The logo ignores OS text scaling. In tight spaces it scales down as a whole and never wraps.

| Placement | Asset |
|---|---|
| Spotlight top nav / compact bar | `LuzLogo(size: 34)` |
| Workspace sidebar | `LuzLogo(size: 30)`; mark only (34) in the collapsed rail |
| Web favicon | `app/web/favicon.svg` + `favicon.png` (48) |
| PWA / Apple touch | `app/web/icons/` (192, 512, maskable full-bleed, 180) |
| Android launcher | legacy `mipmap-*/ic_launcher.png` + adaptive icon (`#131314` background, centred foreground) |
| iOS app icon | `AppIcon.appiconset`, opaque full-bleed squares |
| Web pre-load splash | inline SVG mark in `app/web/index.html` |

## 2. Accessibility rules for neumorphism (non-negotiable)

Pure neumorphism fails WCAG because shapes are defined only by faint shadows. LuzHire keeps the look and fixes the failure:

1. **Text always meets AA** (≥ 4.5:1; large text ≥ 3:1) against `base`, `sunken` and `base-tint`. All pairs in this file have been checked.
2. **Inputs, checkboxes, radios and the search bar have a 1 px `outline`** (≥ 3:1 against `base`) in addition to the inset shadow.
3. **Buttons are identified by their label/icon**, not by relief alone. Icon-only buttons always have a tooltip and a semantics label.
4. **Selected / active state = inset + orange indicator** (a 3 px orange bar, orange icon, or orange dot) — never inset alone.
5. **Focus ring**: 2 px `primary-strong` (light) / `primary` (dark), 3 px offset, on every interactive element.
6. **Disabled = flat** (no shadow) + `disabled` text, so it is clearly different from both raised and pressed.
7. **High-contrast mode**: when the OS requests high contrast (`MediaQuery.highContrast`), replace shadows with a 1.5 px `outline` border on every raised element.
8. Status is never colour-only: chips carry a text label and, where useful, an icon.

## 3. Colors

### Light — porcelain
`base #EEECE7` is the page **and** the fill of every raised element. `sunken #E4E1DA` fills wells (inputs, pressed buttons, kanban columns, chip backgrounds). Shadows: `highlight #FFFFFF` (top-left) and `shade #CBC5BA` (bottom-right). `base-tint #F7E6D8` is an orange-warmed band for the Spotlight hero and CTA sections.
Text: `ink #14110F` (15.9:1), `ink-muted #3D4148` (8.7:1), `muted #5A5F66` (5.5:1 on base, 4.9:1 on sunken). Links and indicators: `primary-strong #9A3F0A` (5.8:1 on base, 5.2:1 on sunken).

### Dark — graphite
`dark-base #1D1F23`, `dark-sunken #16171A`, `dark-highlight #2A2D33`, `dark-shade #0E0F11`, `dark-base-tint #2A1F17`.
Text: `dark-ink #F2F2EF` (14.7:1), `dark-ink-muted #C9CCD1`, `dark-muted #9EA2AA` (6.5:1). Links, focus and indicators use plain `primary` orange (6.5:1).

### Brand
Text on orange is always `on-primary #14110F` (7.5:1). Never white on orange. Orange surfaces glow (`glow-primary`) instead of using the grey shadow pair, so they look lit rather than moulded.

### Theme mapping
Reference light token names in components; the theme layer swaps to the `dark-` twin: `base`, `sunken`, `highlight`, `shade`, `base-tint`, `ink`, `ink-muted`, `muted`, `disabled`, `outline`, `hairline`, all semantic colours and all chip colours. `primary-strong` maps to `primary` in dark.

### Semantic
`success` green, `warning` **yellow** (deliberately not orange), `danger` red, `info` blue. Errors also show an icon and message text.

### Application stage chips (inset pills)
| Stage | Chip | Icon |
|---|---|---|
| Applied | neutral | paper-plane |
| Under review | blue | magnifier |
| Shortlisted | violet | star |
| Assessment | blue | clipboard |
| Technical / HR interview | blue | calendar page |
| Final review | violet | scales |
| Offer issued | orange | envelope with seal |
| Hired | green | handshake |
| Rejected | red | closed folder |
| Withdrawn | neutral, strikethrough | arrow-out |

Job status: Draft neutral · Pending review orange · Published green · Closed neutral · Archived neutral (archive box) · Rejected red.
Company verification: Verified = green chip with a seal/badge icon.

## 4. Elevation & Relief

Light source: **top-left**. Every raised level is a pair of shadows of equal blur — highlight offset up-left, shade offset down-right.

| Token | Use |
|---|---|
| `flat` | disabled controls, table rows, text |
| `raised-xs` | Workspace buttons, kanban cards, icon buttons, nav bar, chips (unselected) |
| `raised-sm` | Workspace panels and stat tiles, Spotlight primary pill |
| `raised-md` | Spotlight job cards, dragged kanban card |
| `raised-lg` | Spotlight feature cards, modals, bottom sheets, command menu |
| `inset-sm` | inputs, pressed buttons, selected chips, status chips, toggle track, active sidebar item, kanban column |
| `inset-md` | hero search bar, dropzones (resume upload), large wells |
| `glow-primary` | orange CTAs |

Rules:
- **Pressing = sinking.** A raised button animates to `inset-sm` while pressed (120 ms), then back.
- **Don't nest relief more than two levels** (e.g. inset input inside raised card is fine; raised chip inside inset well inside raised card is not).
- **Lists:** long lists render cards at `raised-sm` (not `md`) and wrap each item in a `RepaintBoundary`; tables are flat rows inside a single raised panel.
- **Dark theme** uses the same offsets with `dark-highlight` / `dark-shade`; reduce the highlight opacity if it looks chalky.
- **Images and logos** sit in an inset rounded "socket" so they look set into the surface.

## 5. Skeuomorphic metaphors

Use familiar objects where they make meaning clearer; keep them simple, monochrome line icons with soft relief — no photorealistic textures.

| Concept | Metaphor |
|---|---|
| Save job | bookmark ribbon that fills orange when saved |
| Resume / attachments | paper sheet with folded corner; paper-clip on attachments; dropzone looks like an inset tray |
| Interviews | tear-off calendar page showing the day number |
| Notifications | bell with orange dot |
| Delete | trash can; destructive confirm dialog shows the can |
| Archive | archive box |
| Offer | envelope with seal |
| Settings | physical toggles with a raised knob in an inset track |
| Pipeline | paper cards in inset trays (kanban columns) |
| Match score | a round dial (inset track, orange arc) |
| Company verified | wax-seal style badge |
| Search | magnifier inside an inset search well |
| Profile completeness | segmented progress groove filling with orange |

## 6. Typography

- **Plus Jakarta Sans** (700–800): Spotlight display and headings.
- **Inter** (400 / 500 / 600): all UI, body, and Workspace headings (max 600).
- **JetBrains Mono** (400): IDs, audit payloads, keyboard shortcuts.

All are OFL and bundled with the app. Mobile (< 600 px): display 40, h1 34, h2 28, h3 22, h4 19. Body never below 14 px. Support OS text scaling to 200 %.
Text is never embossed or debossed — type stays flat and crisp; relief belongs to surfaces only.

## 7. Layout

- 4 px grid; spacing 4 / 8 / 12 / 16 / 24 / 32 / 48 / 96.
- Shadows need room: keep **≥ 16 px** between raised siblings in Workspace and **≥ 24 px** in Spotlight, and **≥ 24 px** page padding so shadows aren't clipped.
- **Spotlight:** centered column max 1200 px; sections 96 px apart (56 px mobile), alternating `base` and `base-tint` bands.
- **Workspace:** 240 px sidebar + 56 px top bar + content (max 1440 px), 24 px page padding.
- Card grids: 3-up ≥ 1024 px, 2-up 600–1023, 1-up < 600.

## 8. Components

### Spotlight
- **Top nav** (64 px, `raised-xs`): logo; Jobs · Companies · News · For employers; theme toggle (sun/moon physical switch), `Sign in` (raised pill), `Get started` (orange pill). < 768 px: hamburger + `Get started`.
- **Hero search**: `inset-md` pill well with outline, two fields (keyword | location) and an orange "Search" pill sitting inside the well.
- **Filter chips**: raised pills; selected chips sink (`inset-sm`) and show an orange dot. "All filters" opens a bottom sheet (mobile) or side panel (desktop). On mobile, results always come before filters.
- **Job card** (`raised-md`, 18 px radius): logo in an inset socket; title; company + verified seal; inset meta chips (location · type · salary with period); 2-line summary; posted-time caption; bookmark ribbon; match dial when the candidate has a profile. External jobs show "via <source>" and an external-link icon on Apply.
- **Job detail**: two panes ≥ 1024 px with a raised sticky apply panel; mobile uses a raised sticky bottom Apply bar.
- **Candidate dashboard**: greeting + profile-completeness groove; raised cards for Applications (stage chips), Upcoming interviews (calendar pages), Saved jobs, Recommended jobs.
- **Empty states**: one sentence, one action, a simple embossed line illustration with one orange accent.

### Workspace
- **Sidebar** (on `base`): 36 px items; the active item sinks (`inset-sm`) and gets a 3 px orange bar on the left. Collapses to a 64 px icon rail; becomes a drawer < 1024 px.
- **Tables**: one raised panel, flat 44 px rows, `hairline` dividers, row hover = `sunken`, sticky header, mono for IDs.
- **Pipeline kanban**: each stage is an inset tray (288 px) with a stage chip + count; candidates are raised paper cards (avatar, name, title, match dial, applied-ago, next interview). Dragging lifts the card to `raised-md`. Keyboard alternative: focus card → `M` → choose stage. Mobile: stage selector instead of columns.
- **Stat tiles** (`raised-sm`): caption label, ws-title value, delta chip. Real numbers only; "—" when no data.
- **Command menu** (`Ctrl/⌘ K`): raised-lg panel with an inset search well.
- **Forms**: labels above inset fields; helper text `muted`; errors `danger` + icon below the field; the job editor shows a live preview of the public job card.

### Shared
- **Toggles**: inset track, raised knob; track fills orange when on.
- **Checkbox / radio**: inset well with outline; checked = orange fill with ink check / dot.
- **Sliders** (salary range): inset groove, raised thumbs, orange filled segment.
- **Status chips**: inset pills (see §3).
- **Toasts**: ink background (flat), bottom-center mobile / bottom-right desktop, 4 s, Undo for destructive actions.
- **Skeletons**: `sunken` blocks with a soft shimmer; no spinners for lists.

## 9. Motion

120 ms press (raised → inset), 200 ms chips and toggles (knob slides with slight overshoot), 280 ms sheets, dialogs and page transitions; easing `cubic-bezier(0.2, 0, 0, 1)`. Shadows animate by interpolating offset and blur. Realtime inserts (new applicant, new notification) rise from flat to raised. Reduced-motion: no movement, opacity only.

## 10. Responsive Behavior

| Name | Width | Behavior |
|---|---|---|
| compact | < 600 | bottom navigation (candidate), drawer (workspace), single column, bottom sheets; shadows step down one level |
| medium | 600 – 1023 | navigation rail, 2-up grids, kanban scrolls horizontally |
| expanded | 1024 – 1439 | full sidebar, two-pane job search, 3-up grids |
| large | ≥ 1440 | content capped (1200 Spotlight / 1440 Workspace) |

Touch targets ≥ 48 × 48 dp; Workspace controls may be 38 px tall on pointer devices only.

## 11. Flutter Implementation Notes

- Tokens: `app/lib/core/theme/tokens.dart` (generated from this front matter). `AppTheme.light()` / `AppTheme.dark()` build Material 3 `ThemeData` with `scaffoldBackgroundColor = base`, and a `ThemeExtension<LuzTokens>` carries `base`, `sunken`, `highlight`, `shade`, chip colours and the elevation shadow lists.
- **Relief is implemented with `BoxShadow` pairs** (`LuzRelief.raised(level)` / `LuzRelief.inset(level)`). Inset shadows are not supported by `BoxShadow`, so `LuzInset` paints them with a `CustomPainter` (or the `flutter_inset_shadow` package).
- Core widgets: `LuzSurface` (raised/inset/flat container), `LuzButton` (raised → inset on press, orange variant), `LuzIconButton`, `LuzTextField` (inset + outline), `LuzChip`, `LuzToggle`, `LuzDial`, `LuzCard`, `LuzStageChip`. A `Zone` inherited widget (`spotlight` | `workspace`) sets default depth, radius and density.
- Respect `MediaQuery.highContrastOf(context)` → outline mode; `MediaQuery.disableAnimationsOf(context)` → no movement.
- Performance: cap shadow blur at 24 px, prefer `raised-sm` in scrolling lists, wrap list items in `RepaintBoundary`.

## 12. Prompt Guide (for Stitch and coding agents)

Always state **zone**, **theme**, **breakpoint**, and "accessible neumorphism":
- *Spotlight:* "LuzHire job search, Spotlight zone, accessible neumorphism, light porcelain theme (#EEECE7), desktop 1280 px. Everything moulded from one surface colour with top-left light. Inset pill search well with outline and orange Search pill; raised filter chips (selected chips sink with orange dot); raised job cards (18 px radius) with inset logo socket, bookmark ribbon and match dial. Text high-contrast and flat. Use DESIGN.md tokens only."
- *Workspace:* "LuzHire employer pipeline, Workspace zone, accessible neumorphism, dark graphite theme (#1D1F23), desktop 1440 px. Shallow relief: sidebar with sunken active item and orange bar; kanban stages as inset trays holding raised paper cards; flat table rows inside one raised panel."
- Always produce light and dark variants and a 390 px mobile variant.
- Work one component at a time by its `components:` name.

## 13. Do's and Don'ts

**Do**
- Keep one surface colour per theme; express hierarchy with relief, not new colours.
- Pair every raised/inset state with a non-shadow cue where meaning is involved (label, outline, orange indicator).
- Keep orange scarce: one signature orange CTA per screen.
- Use honest skeuomorphic metaphors for icons; keep them simple line icons.
- Show real data or an honest empty state.

**Don't**
- Rely on shadow alone to show a boundary, selection or state.
- Emboss or deboss text, or use low-contrast grey-on-grey text.
- Stack more than two relief levels, or use relief on every element of a dense table.
- Use photorealistic textures (leather, wood, paper grain).
- Put white text on orange, or use orange for warnings.
- Show invented metrics, placeholder company facts, or decorative "AI" percentages.

## 14. Known Gaps

- Illustration set (embossed line style) still to be produced in Stitch.
- Chart palette for analytics: start from chip hue families; bars and lines sit in an inset plot well.
- Transactional email styling is flat (email clients can't render relief).
