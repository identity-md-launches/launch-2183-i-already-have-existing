# IMDPot: connected website release

This updates the existing [IMDPot jackpot room](https://imdpot-the-imd-jackpot-room.sites.imd.fun/) to the confirmed, newly deployed contract. The existing React interface, casino-chip artwork, dark green/lime styling, navigation, Privy login and wallet sheet are preserved. The finished static website is in `dist/`; serve its contents at the existing site. This task does not publish a website or send any mainnet transaction.

**Mainnet setup still required:** the live contract reports `isConfigured() == false` and its token is unset. The current contract owner must connect on Ethereum, open **Owner controls → Configure IMD token**, review the addresses, and confirm **Set IMD token permanently**. The interface supplies the IMD token from the pinned network handoff. This is the contract's supported one-time owner setting, not a missing deployment value. Everyone else sees “Awaiting setup”; no entry approval is requested while it is unset. No key is needed in the site or repository.

## Confirmed deployment

| Field | Value |
| --- | --- |
| Network | Ethereum mainnet, chain ID 1 |
| Game | `0xa5ee8a1f2aa98f08755f80bb278528d789f1e8f3` |
| Deployment block | `26221596` |
| Deployment transaction | `0x3409199f4b2e8faa6a01fa2cada460fe93b6232df5b7b3b0151a3d33c21de738` |
| Pinned source commit | `b60026be5455bdeed5a8adc224fe0ef57ffe68f4` |
| IMD for owner setup | `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7` |

`web/deployment.json` holds the confirmed address, block and runtime hash. `web/release.json` preserves the handoff's ABI/creation hashes and source commit. `web/network.mjs` holds the pinned public RPCs, chain and token. The existing `web/game-abi.mjs` exactly matches the ABI compiled from `src/IMDPot.sol`; its canonical, recursively key-sorted JSON has Keccak-256 `a27f9c231b09f0748e8915b14da5af392b2bdccde463016cb7900609269a96fb`.

The live chain ID, compiled and deployed runtimes, first block with code, and successful factory deployment receipt were checked. Publicnode requires a token for historical code queries; the pinned secondary RPC answered those checks. The game code is checked again before every transaction. See [chain verification](docs/validation/chain-verification.json).

## Install, rebuild and preview

Use Node 22+, Python 3, and Foundry when compiling or testing the contracts. The existing site's browser modules are already local, so its production build needs no package download. The frontend manifest and lockfile are confined to `web/`. To install the locked development tool without putting dependency/cache directories in the submission:

```sh
mkdir -p /tmp/imdpot-dev
cp web/package.json web/package-lock.json /tmp/imdpot-dev/
npm ci --prefix /tmp/imdpot-dev --cache /tmp/imdpot-npm-cache
/tmp/imdpot-dev/node_modules/.bin/tsc --noEmit -p web/tsconfig.json
npm --prefix web run build
npm --prefix web run preview
```

Open `http://localhost:4173/`. Stop the preview with Ctrl-C. `python3 tools/export_site.py` is the equivalent build command. It checks the ABI/handoff, then recreates `dist/` using an explicit set of runtime files. It excludes development manifests, types, tests and caches. All entry URLs are relative; hash navigation needs no server rewrites. `dist/` contains the local font, favicon, social image, wallet icons and SDK chunks. Do not add dependency directories or package archives to Git.

This project retains the supplied, captured React build rather than replacing it with a new scaffold. The application portion of `web/assets-future-v1/index-IgEJPNDv.js` and its CSS are formatted for maintenance; bundled library internals retain their existing form. TypeScript checks the deployment boundary, configuration, runtime verifier, timer/draw rules and purchase module through JSDoc and `web/types.ts`. It does not typecheck the legacy bundled React/SDK internals.

## Play and administer

1. Connect with a named EIP-6963 browser wallet, Coinbase Wallet/Smart Wallet, or the existing Privy email flow. On a phone without injection, the sheet opens the current page in MetaMask, Coinbase Wallet, Rabby or Phantom. No WalletConnect relay or project ID is configured.
2. After owner setup, choose whole tickets, review the current round and full game address, approve the exact IMD cost if needed, then confirm `buyTicketsForRound`. ETH pays network gas. Approval alone does not buy tickets. Balance, deadline, pause, round and wallet account/network are checked again before submission.
3. The first confirmed purchase starts 900 seconds. The clock uses the latest Ethereum block time plus elapsed time between reads; later buys do not extend it. Reads refresh every 15 seconds. Data more than a minute old disables transactions and offers a retry.
4. Once entries close, anyone selects **Finalize round** to commit a target three blocks ahead. After that block is mined, **Settle winners** is enabled through target + 256. Settlement opens the next round; winners select **Claim prizes**.
5. **Round tools & refunds** supports cancellation after the blockhash window expires, eligible paused cancellation, refund lookup/claim, and retrying deferred fees. The owner panel also pauses/resumes entries. A committed draw can still settle while paused.

The original economics remain: 40/20/10% prizes, 10% burn, 5% house and 15% permanent lock; 0.1 IMD per ticket; settled-ticket loyalty points and the existing multiplier rules. Future-blockhash randomness can be influenced by block producers. Keep that existing explanation visible when changing the UI. See [contract security notes](docs/SECURITY.md).

## Checks and actual results

Run from the repository root after building the contracts and site:

```sh
forge build
npm --prefix web run build
/tmp/imdpot-dev/node_modules/.bin/tsc --noEmit -p web/tsconfig.json
npm --prefix web test
python3 -m unittest discover -s test -p test_release.py -v
node test/site.integration.mjs
node tools/verify_deployment.mjs --live
```

Actual results on 2026-10-19: Solidity compilation passed (existing lint warnings); production export passed; strict integration-module typecheck passed; 15 Node tests and 4 Python release tests passed. The Anvil integration passed approval/purchase, chain deadline, commit/settle, claims, expired-draw cancellation and refund. The live verification passed and confirmed that owner token setup remains pending.

`test/browser.integration.mjs` serves the real `dist/` under `/preview/`, deploys the real Solidity on an isolated Anvil chain, and intercepts all public RPC requests. Its in-browser EIP-1193 test provider can send only to that local chain; it contains no signing key. Chromium passed the complete UI purchase, draw, claim, owner setup/pause/resume, cancellation/refund and failure/retry flows, phone wallet links, keyboard checks, and overflow checks at 320/390/768/1440. Optional axe-core scanning found no WCAG A/AA violations in three inspected states. The final pinned taste probe passed **16/16** checks, including reduced motion and the 390px first screen.

For browser checks, install Playwright and axe-core outside the repository, install its Chromium browser, set `IMD_PLAYWRIGHT` to Playwright's `index.mjs` and `IMDPOT_AXE` to `axe-core/axe.min.js`, then run:

```sh
node test/browser.integration.mjs
node .imd/reads/skills/design-critic/scripts/taste.mjs --out test/scratch/taste
```

The second command uses the pinned assignment input and is available while that input is present. Browser paths/cache directories can be selected with `PLAYWRIGHT_BROWSERS_PATH`; this worker also used temporary `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` directories for its functioning Chromium fallback.

Limitations: the supplied browser connector crashed on startup; local Playwright Chromium was used successfully. WebKit downloaded but could not start because its host libraries were missing. No physical wallet app, Coinbase passkey creation, Privy email delivery, screen reader or native browser 200% zoom was tested. No mainnet purchase/setup was signed, and the existing public URL has not been republished by this worker. These checks are worker evidence, not independent certification. Full six-domain design coverage, fixes, limitations and screenshots are in [validation](docs/validation.md); implemented design values are in [DESIGN.md](DESIGN.md).
