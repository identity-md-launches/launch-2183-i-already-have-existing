# IMDPot integration and design validation

Worker review, 2026-10-19. This is evidence of local checks, not an independent certification.

| Area | Result |
| --- | --- |
| Existing website retained | Yes: captured React application, styling, artwork, navigation and wallet/Privy flows |
| Confirmed new contract | ABI/creation/runtime hashes and live deployment checks passed |
| Product and primary action at 390×844 | Yes, screenshot inspected and action bounds asserted |
| Production build / integration typecheck | Passed / passed |
| Node / Python / actual-contract integration | 15/15; 4/4; passed |
| Chromium production-UI checks | 15 grouped checks passed, including three axe audits |
| Final taste@1 | 16/16 checks passed |
| Mainnet prerequisite | Owner's supported one-time token setup remains pending |
| Browser limits | WebKit could not launch; no physical wallet or screen-reader session |

## Scope and consequential assumptions

The requested change is the existing website's connection to the newly deployed game, not a new website. `web/` is the editable site; `dist/` is the production static export. The original bundled React/SDK modules are retained. The application portion and CSS were formatted to make the changed source reviewable. A small dependency-free export script preserves those modules and their relative paths instead of introducing a different frontend stack.

The deployment and network inputs were copied into durable, public release/configuration files. Compilation from the supplied Solidity source produced the exact pinned canonical ABI hash and creation-code hash. The local runtime hash also matches Ethereum. At the observed mainnet head **26,225,955**, the new game was unpaused, on round 1, with its token unset. That is real state, not an invented configuration. The provided design explicitly supports the owner's one-time token setting; the site offers it using the pinned IMD address. No mainnet setup, approval or purchase was signed. The existing domain is for the publisher to update with this export.

The one visual idea remains the current pine-green jackpot table with a lime ticket action and chip artwork. English and dark appearance are the existing supported variants. Light mode, localization and an unrelated redesign were outside scope.

## Requirements

| Brief requirement | Evidence / status |
| --- | --- |
| “Use the existing IMDPot website” / “Do not create a new website” | Preserved capture in `web/assets-future-v1/`, original favicon/social card and public Privy settings. Met. |
| “Connect this newly deployed contract” | `web/deployment.json`, `web/release.json`, `web/network.mjs`; runtime verification before reads/transactions. Met. |
| “Game becomes fully playable” | Production UI tested against the actual Solidity on isolated Anvil: owner configuration, exact approval/buy, chain countdown, both finalize calls, claim, pause/resume, expiry cancellation and refund. Mainnet owner setup is still required. |
| “usable website … working primary interactions and responsive layouts” | Chromium UI tests at 320/390/768/1440; rejection/retry and keyboard paths. Met within recorded browser coverage. |
| “dist/index.html and its assets … source and lockfile … relative asset URLs” | Complete export with source and `web/package-lock.json`; subpath requests, entry references and runtime-copy equality tested. Met. |
| “production build, typecheck and useful interaction validation” | Commands and actual outcomes below. Met. |
| “pinned Better Interface … six domains” | Guide read before implementation; coverage and corrected findings below. Met within listed limitations. |
| “first screen at 390 … title, favicon, description, og:title and og:image” | Primary button bottom is within the viewport; `web/index.html` metadata references existing local assets; share probe passed. Met. |
| “DESIGN.md … tokens, typography, components and responsive behavior” | Root `DESIGN.md` extracted from final CSS/application and rendered checks. Met. |
| “README … install, preview and rebuild” | Root README documents isolated tool installation, production build, preview, tests and live setup. Met. |

No fabricated players, balances, winners, timer starts or successful transactions were added. Screenshots with connected-owner/gameplay data are explicitly from the isolated local-chain check.

## Better Interface coverage

The pinned contents/workflow and core principles of accessibility, layout, writing, typography, colors and UI were read. Relevant dialog/forms, focus, hit-area, motion, wrapping and documentation guidance was applied. Existing visual choices were authoritative.

| Domain | Checked source and rendered evidence | Not performed / not applicable |
| --- | --- | --- |
| Accessibility | Native labeled fields/buttons/disclosures/dialog, one main/heading outline, skip link, focus token, validation association, error/status roles. Chromium field-error focus, Escape/return focus and modal tab sequence checked. Native browser-chrome focus is allowed; background page controls remain inert. Three axe-core WCAG A/AA scans reported zero violations. | No actual screen reader, physical-device assistive technology or native 200% browser zoom. Axe had manual-review items, detailed below. |
| Layout | Original grids/margins preserved. First screen at 390 visually inspected and primary action bounds tested. 320/390/768/1440 reflow, long addresses, owner content and phone sheet checked. Probe found no scroll, overlaps, floating-control obstruction or clipping. | Arbitrary widths, translated copy and physical safe-area hardware untested. No other locales are implemented. |
| Writing | Existing five-word headline and plain supporting sentence retained. Purchase explains approval versus entry, exact cost, ETH gas and permanent lock. Owner setup names its irreversible effect. Chain/wallet failures offer recovery. Empty history reflects chain data. | No localization review; not an implemented feature. |
| Typography | Local Geist file restored and loaded without a failed resource request. Six source sizes, three used weights, tabular changing numbers, 16px inputs and address wrapping checked. Probe found five rendered sizes at each measured entry width. | No manual font-axis or iOS auto-zoom device inspection. Native zoom untested. |
| Colors | Semantic source pairs computed in `contrast.json`; ordinary text pairs range from 5.84:1 to 16.46:1 in that selected set. Probe passed rendered solid-background contrast. Text/status cues supplement hue. Focused phone wallet row screenshot inspected. | Does not establish every composited backdrop/hover pair or legal accessibility compliance. Light theme is absent. |
| UI | Existing flat panels, single primary action per surface, SVG icons, pending/success/error/retry states, phone sheet, account/network states and pressed/disabled states reviewed. Hover is pointer-gated; reduced-motion probe passed with no endless animations or `transition: all`. | No 10%-speed animation-panel review; only 150ms property transitions/press scaling exist. Real Coinbase passkey/Privy/phone app handoff requires external services/devices and was not exercised. |

Axe-core's initial `aria-prohibited-attr` manual-review item identified two generic divs with group labels. They now have `role="group"`; the final initial-game scan has no incomplete items. Dialog scans still return `color-contrast` for manual review under the native modal/backdrop. Those subchecks are not counted as automated passes. The solid text/background pairs were separately computed and the rendered dialogs inspected; no full screen-reader or composited-contrast claim is made.

## Findings and fixes

| Severity / source | Finding, concrete fix and recheck |
| --- | --- |
| High — `web/deployment.mjs:4`, `web/deployment.json:1` | The checkout's guard awaited a nonexistent deployment handoff and prevented game startup. Added the actual pinned address/block/runtime hash, durable release metadata and an offline/live verifier. Runtime and deployment receipt checks passed, and the production UI read the new game. |
| Medium — `web/assets-future-v1/index-DdqXwvQ8.css:6` | The captured CSS referenced a missing Geist WOFF2 (initial probe render failure / 404). Restored that exact asset from the existing site, retained its OFL, rebuilt. Final probe: zero missing local files, 16/16 checks. |
| Medium — `web/assets-future-v1/index-IgEJPNDv.js:436`, `web/wallets/` | Wallet rows referenced marks absent from the checkout. Copied MetaMask/Coinbase/Rabby/Phantom SVGs from the existing website. Phone sheet screenshot and resource checks show the marks, without local 404s. |
| Medium — `web/assets-future-v1/index-IgEJPNDv.js:887` | Owner setup could retain a player query whose token balance was undefined until the next poll, blocking an immediate first entry. Added token configuration to the player query key. Browser owner-setup → purchase passed without waiting for the periodic refresh. |
| Medium — `web/assets-future-v1/index-IgEJPNDv.js:3063`, `web/assets-future-v1/index-IgEJPNDv.js:1651`, `web/assets-future-v1/index-DdqXwvQ8.css:1328` | Transaction-critical addresses were abbreviated in review/owner details. Show complete addresses and permit wrapping. Purchase review screenshot, dialog overflow assertion and owner reflow checks at 320–1440 passed. Header's conventional short connected address remains. |
| Medium — `web/assets-future-v1/index-IgEJPNDv.js:1187`, `web/assets-future-v1/index-IgEJPNDv.js:2455` | Preset/filter labels were attached to generic divs without group semantics. Added the appropriate group roles. Final axe initial-game scan: zero violations and no incomplete items. |

Existing hierarchy, brand colors, chip artwork and original copy were retained. The final entry probe has no failed checks. Ten of its 25 phone controls are below the 44px comfort target but all satisfy the 24px/spacing check; these are inherited compact navigation/help controls. The primary action, quantity/preset controls and wallet rows have comfortable targets.

Validation scaffolding also needed repairs: wait for Anvil receipts to be mined, resolve test assets independently of the npm working directory, and use unique local socket names across concurrent isolated processes. These were harness defects, not mainnet game failures. The final commands below passed after those repairs.

## Commands, outcomes and evidence

| Command actually run | Outcome |
| --- | --- |
| `forge build` | Exit 0; exact Solidity 0.8.26 build, with existing lint warnings. No contract/dependency/build-configuration edit. |
| `npm install --package-lock-only --ignore-scripts --prefix web --cache /tmp/imdpot-npm-cache` | Exit 0; real frontend lockfile, no root manifest/lockfile or repository dependency directory. |
| `npm --prefix web run build` | Exit 0; explicit static export after pinned ABI, creation and runtime checks. |
| `/tmp/imdpot-build-tools/node_modules/.bin/tsc --noEmit -p web/tsconfig.json` | Exit 0; strict JSDoc/TypeScript integration boundary. Legacy bundled React/SDK code excluded. |
| `npm --prefix web test` | Exit 0; 15/15 passed. Includes exact exported runtime copies, relative local metadata assets, ABI parity and purchase/draw boundaries. |
| `python3 -m unittest discover -s test -p test_release.py -v` | Exit 0; 4/4 passed. |
| `node test/site.integration.mjs` | Exit 0; actual Anvil deployment/release, purchase, deadline, commit/settle, claim, expiry cancellation and refund. |
| `node tools/verify_deployment.mjs --live` | Exit 0; real chain/runtime/first-code-block/receipt validation. Secondary pinned RPC supplied archive reads. `docs/validation/chain-verification.json` records actual state. |
| `node test/browser.integration.mjs` with installed Playwright/Chromium and `IMDPOT_AXE` | Exit 0; 15 grouped checks, zero page exceptions and zero failed local resources. `docs/validation/browser-results.json` records checks/audit limits. |
| `node .imd/reads/skills/design-critic/scripts/taste.mjs --out test/scratch/taste` with installed Playwright/Chromium | Exit 0; **16/16**. Measures 320/390/1440 plus reduced motion; screenshots visually inspected. Retained report: `docs/validation/taste.json`. |
| Browser connector navigation | Failed at Chromium startup with crashpad/closed-browser error. Local Playwright worked using temporary XDG directories. |
| Playwright WebKit installation and `IMDPOT_BROWSER=webkit node test/browser.integration.mjs` | Download succeeded, launch failed for missing host libraries including GTK4/GStreamer. No WebKit interactions claimed. |

The browser script serves the actual export at `/preview/`. Its EIP-6963 provider is test-only. All public-RPC traffic is intercepted and forwarded to an isolated Anvil deployment of the actual contract at the handoff addresses; no production configuration is replaced and no external write is possible. It validates exact token approval and `buyTicketsForRound`, receipt state, wallet rejection, network switching, owner setup/pause/resume, deadline/commit/settlement/claim, expired cancellation/refund, loyalty non-accrual on cancellation, simulated 61-second stale data, failed RPC recovery, phone links and responsive overflow.

The mainnet taste screenshots show the actual unconfigured round. Other screenshots show local-chain state and are labeled in their filenames. A screen capture is not evidence of a real mainnet signature or an actual mobile wallet opening.

Retained visual evidence in `docs/validation/` (also mirrored under the assignment output folder `artifacts/`):

- `390-mainnet-first-screen.png`: the real read-only entry, game and main action visible.
- `1440-mainnet-first-screen.png`: preserved desktop composition.
- `390-local-purchase-review.png`: full address, cost and approval explanation.
- `390-local-wallet-sheet.png`: mobile links and visible keyboard focus.

Browser console review: 64 expected `net::ERR_FAILED` entries were captured while the test deliberately aborted the two pinned RPCs. There were no warnings/errors outside that forced-outage phase. The retry then restored contract data; raw console entries are retained in `docs/validation/browser-results.json`.

## Completion and limitations

The repository implementation and production export are complete for the requested integration. There are no remaining known application failures from the executed checks. Mainnet gameplay begins after the legitimate owner performs the supported one-time token setup; that action is deliberately exposed, not guessed or signed by the worker. The live URL has not been published by this job.

Browser coverage is Chromium only. Actual mobile apps, Coinbase passkey creation, Privy email delivery, real-wallet signatures, screen readers, native 200% zoom and WebKit remain unverified. No claim of full accessibility compliance or independent behavioral certification is made. The final path/byte audit is recorded in `docs/validation/submission-budget.json`; required source/runtime assets remain complete, with dependencies/caches/temporary package archives outside the submission and no ignore-file change.

The assignment output folder `artifacts/` is excluded from the Git candidate set. The validation report and evidence are therefore also retained in the allowed `docs/` paths, so README/design references resolve in the submitted repository. Ignore rules were not changed.
