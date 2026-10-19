# LuzHire screen designs (Google Stitch)

Reference screens generated with the Stitch MCP from our own [`DESIGN.md`](../../DESIGN.md).
Stitch project `projects/9802537347684928858`, design system "LuzHire Accessible Neumorphism"
(`assets/e7eaf9641ec14d9ca452e9238ded3026`). `stitch/screens.json` maps each file to its Stitch screen.

Each screen has a `.png` (screenshot) and an `.html` (Stitch's static export, for inspecting spacing and copy).

| Screen | Light | Dark | Built in |
|---|---|---|---|
| Home (Spotlight) | [desktop](stitch/home-desktop.png) · [mobile](stitch/home-mobile.png) | [desktop](stitch/home-desktop-dark.png) · [mobile](stitch/home-mobile-dark.png) | Phase 1 (hero, disciplines, employer band); live jobs and banner in Phase 4 |
| Job search | [desktop](stitch/jobs-search-desktop.png) · [mobile](stitch/jobs-search-mobile.png) | — | Phase 4 |
| Job detail | [desktop](stitch/job-detail-desktop.png) · [mobile](stitch/job-detail-mobile.png) | — | Phase 4 |
| Candidate dashboard | [desktop](stitch/candidate-dashboard-desktop.png) · [mobile](stitch/candidate-dashboard-mobile.png) | [desktop](stitch/candidate-dashboard-desktop-dark.png) | Phase 5 |
| Employer pipeline (Workspace) | [desktop](stitch/employer-pipeline-desktop.png) | [desktop](stitch/employer-pipeline-desktop-dark.png) | Phase 6 |
| Admin verification queue (Workspace) | [desktop](stitch/admin-queue-desktop.png) | — | Phase 7 |

## How to use these designs

The designs set **layout, hierarchy and density**. `DESIGN.md` and `lib/core/theme/tokens.dart` stay the source of truth for colours, radii, shadows and type. When building a screen:

- **Use the `Luz*` widgets and tokens.** Never copy hex values or CSS from the HTML exports.
- **Use fictional companies.** Stitch filled the mockups with real Indian company names. The app shows only our seed data (`supabase/seed.sql`) or real employers who sign up.
- **No invented numbers.** Stitch added stats such as "₹22.4 LPA average", "4.2 days to first interview" and "2,400 openings". Show a number only when it comes from the database.
- **Match scores and "AI matching" are out of scope** unless they are added to the roadmap. Leave those panels out.
- **Keep the accessibility rules** (DESIGN.md §2). Status chips use an icon plus text, selection uses the orange indicator, and inputs keep their outline.
