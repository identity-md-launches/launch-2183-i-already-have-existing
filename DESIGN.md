# IMDPot implemented design

## Overview

IMDPot is the existing Ethereum jackpot room: the current round and ticket purchase form lead, with draws, personal balances, history and administration below. This release preserves its pine-green surfaces, lime action, Geist typography and poker-chip illustration. It connects the supplied interface to the confirmed fresh contract; it introduces no replacement site or marketing page.

The canonical styling is `web/assets-future-v1/index-DdqXwvQ8.css`. Its formatted React application is `web/assets-future-v1/index-IgEJPNDv.js` after the “Existing application” comment. Deployment and purchase rules live in the small modules directly under `web/`.

## Colors

The root defines primitive pine/sage/lime/cream/status colors, then semantic aliases. Components use the semantic names. The sole supported appearance is dark; there is no light-theme toggle.

| Semantic token | Resolved value | Use |
| --- | --- | --- |
| `--color-page` | `#111612` | Page |
| `--color-sidebar` | `#0d120f` | Desktop navigation |
| `--color-surface` | `#18201a` | Panels and dialogs |
| `--color-table` | `#1b281e` | Current jackpot panel |
| `--color-hover` | `#222d25` | Hover/selected neutral controls |
| `--color-border` | `#2f3c32` | Structural dividers |
| `--color-control-border` | `#455649` | Resting control boundaries |
| `--color-text` | `#f1f4eb` | Main text |
| `--color-secondary` | `#a8b5a7` | Descriptions, `.muted` and supporting labels |
| `--color-muted` | `#8e9d8d` | Quieter secondary decoration/text |
| `--color-accent` | `#d3f36a` | Primary action and established brand details |
| `--color-accent-hover` | `#dff88e` | Primary hover |
| `--color-on-accent` | `#172015` | Text on lime |
| `--color-focus` | `#f1f4eb` | Focus perimeter |
| `--color-success` | `#8bd9a5` | Confirmed transactions |
| `--color-burn` | `#efb28a` | Burn activity |
| `--color-error` | `#ffb3ad` | Errors |

Statuses also have words/icons. Data is never distinguished by color alone. Pool chip artwork uses the existing lime/pine palette. The three podium positions keep their established gold/silver/bronze tints in `.podium`; they are ordinal decoration, not additional actions. Measured source color pairs and rendered-review limits are in `docs/validation/contrast.json` and `docs/validation.md`.

## Typography

`Geist Variable` is bundled locally as `geist-latin-wght-normal-BgDaEnEv.woff2`; the fallback is `-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif`. The `@font-face` declares normal weights 100–900 and `font-display: swap`; the application uses 400, 500 and 600. The font's OFL is beside the asset. No remote font request is required.

| Token | Value | Role |
| --- | --- | --- |
| `--text-caption` | `0.8125rem` / 13px | Captions, controls and dense dashboard labels |
| `--text-body` | `1rem` / 16px | Body, fields, minor headings |
| `--text-heading` | `1.25rem` / 20px | Section headings; phone headline |
| `--text-title` | `1.75rem` / 28px | Desktop headline and phone countdown |
| `--text-stat` | `2.5rem` / 40px | Phone pool / larger values |
| `--text-pool` | `4rem` / 64px | Desktop pool |

The root is 16px with unitless 1.5 line-height. H1 uses 1.2 line-height and −0.035em tracking, H2 1.3/−0.02em, H3 1.4. Phone H1 uses −0.025em. Headings balance, descriptions use `text-wrap: pretty`, and long explanations have character-based measure caps. Prices, ticket counts and timers use tabular numerals. Inputs are at least 16px. Review/owner addresses wrap with `overflow-wrap: anywhere`; a purchase review shows the complete contract address. The connected header deliberately uses the wallet convention of a short checksummed address with access to its wallet dialog/explorer link.

## Layout

Desktop has a fixed 216px sidebar and matching `.app-shell` inset. Main content is centered at at most 1344px, with 40px horizontal padding. The header is at least 88px high. The leading `.play-grid` uses `minmax(0, 1.45fr) minmax(0, 1fr)` with a 20px gap; panels have 26px padding. Content stays in normal flow and the ticket action stays inside its panel.

Spacing is implemented as repeated literal values, not fictional spacing tokens: common gaps are 8/12/16/20/24/28/32px, with 40/48px for larger groups. Reuse the existing grid, section-head, field and panel patterns.

| Breakpoint | Implemented adaptation |
| --- | --- |
| ≤1190px | Sidebar 192px, horizontal padding 28px, panels 22px, tighter grids/art |
| ≤980px | Sidebar 82px icon rail; nonessential artwork and help link are hidden |
| ≤760px | Sidebar replaced by mobile brand/header and hash-navigation row; padding 24px |
| ≤620px | One-column play/dashboard/history, 16px page margins, 20px panel padding, 16px panel radii; dialogs become bottom sheets |
| ≤360px | Extra chip artwork hidden; tighter panel margins, refund controls stack |
| ≥1600px | Main top padding increases to 48px |

The 390×844 first screen includes the product, quantity field, total and Buy tickets. Chromium checks covered 320, 390, 768 and 1440 CSS pixels, including connected-owner content and modal addresses, without horizontal page overflow. These are tested viewports, not a claim that every possible size or physical device was inspected.

## Elevation & depth

Panels separate through tone and spacing, with no decorative shadows. Dividers/borders communicate structure and control states. The native dialog is the raised surface: `0 24px 80px #0008` shadow, no border, and `#050906bd` backdrop in the browser top layer. The skip link uses z-index 30; the Privy loading status uses 10. The header does not float over the reading surface.

## Shapes

Desktop panels use `--radius-panel: 20px`, phone panels 16px, and controls use `--radius-control: 10px`. Dialogs are 24px; phone dialogs keep rounded top corners and respect `env(safe-area-inset-bottom)`. Wallet marks use 6px corners; status dots and icon controls are round. Decorative SVG chips retain their existing geometry.

## Components

| Pattern / source symbol | Reuse and behavior |
| --- | --- |
| `.button.primary`, `.secondary`, `.wallet-button` | Lime emphasizes the purchase or current modal confirmation. Neutral alternatives retain visible control borders. Most buttons have 46px minimum height; the phone header wallet control has 42px. Disabled controls dim and use native `disabled`. |
| Quantity field / `ci()` | Visible label, numeric keyboard, decrement/increment, named 1/10/50/100 preset group, exact computed total. Submit validation sets `aria-invalid`, announces its error and returns focus to the field. Activity filters likewise use a named group with pressed states. |
| Shared dialog / `kr()` | Native `dialog.showModal()`, accessible title, close button, backdrop dismissal, Escape, inert background and focus restoration. Desktop maximum width 440px; phone bottom sheet has scrolling and a 90dvh cap. |
| Connection / `Vr()`, `Hr()` | Named EIP-6963 wallets and Coinbase, phone wallet browser links, existing optional Privy email sign-in. One header control shows connection/network state and exposes disconnect. Wallet rows are at least 56px. |
| Game/player reads / `Jr()`, `Zr()` | Verified contract reads, explicit loading/empty/error states and retries. Player query identity includes token configuration so first-time setup refreshes balances immediately. |
| Transactions / `ti()` | Review, simulation, pending/signature/confirmation, receipt status and recoverable rejection. Explorer links and the persistent transaction banner expose status after a dialog closes. |
| Owner panel / `oi()` | Only the on-chain owner's connected address sees controls. Token setup and pause/resume require explicit review; addresses remain readable. |
| Round tools / `ai()` | Native disclosure for cancellation, deferred fees and refund lookup; rules and recovery text stay beside controls. |
| Icons / `P()`, `Or()` | Existing currentColor SVG icon family and chip artwork; decorative icons are hidden from assistive technology. Wallet brand marks remain in their original colors. |

`:focus-visible` uses a 2px cream outline with 4px offset; forced-colors switches to system `Highlight`. Hover styles are gated by `hover: hover`. At no reduced-motion preference, named properties transition for 150ms and presses use `scale(0.96)`; reduced motion has neither transition nor scale. There are no endless animations or page-load entrances.

## Do's and don'ts

- Reuse semantic colors and the six-size scale. Keep the game/purchase visible before explanations on phones.
- Build another hash section with `.section-head`, `.panel` or the existing flat section pattern; reuse native fields, dialog and transaction flow.
- Keep complete transaction-critical addresses, exact amounts, gas explanations and action results available. Never substitute sample balances or fabricated history for failed chain reads.
- Keep contract configuration in the handoff modules and token setup in the owner transaction. Do not scatter addresses through new UI code.
- Preserve dark-only styling, the existing illustration and the compact dashboard voice. Avoid adding another hero, nested cards, competing filled actions or extra typefaces.

Design review used the pinned Better Interface guidance by Jakub Krehel (MIT, commit `267330e1adfc66a718fb65fa6918c1f06d0a689e`). This documentation method follows Paul Bakaus's Impeccable document reference (Apache-2.0, commit `9d715cc4f5564a990ca8345abfdd5df6dc9b41c8`). Notices/licenses are retained in `docs/licenses/design-guidance.txt`.
