# IMDPot fresh deployment

This repository delivers a new, non-upgradeable `IMDPot` application and the existing website adapted to consume its confirmed deployment. It does not interact with, upgrade, migrate balances from, or transfer approvals from the previous contract.

The assignment workspace contained only the pinned review inputs. Neither the previous job's Solidity source nor the website's source project was present. The public site's published application already contained a future-blockhash ABI, owner controls, Privy support and the game rules below. This implementation reproduces that interface and behavior from those public inputs; it is not claimed to be the previous contributor's exact source.

**Release status:** the application is ready for the network's independent review, manifest and factory deployment stages. No Ethereum transaction was signed or broadcast here and the live site has not been republished. A new address does not exist in this deliverable. The launch service supplies its confirmed address and deployment block, then the site operator builds and publishes the verified site release. There is intentionally no `launch.json` or guessed deployment address.

## Build and check

From this repository's root:

```sh
forge build
FOUNDRY_FUZZ_SEED=0xcbd2a37cf5739138e3a0b29daa90709680ffd9f670aa9e75ae42c8ba98a991ee forge test
forge fmt --check
node --test test/web.test.mjs
python3 -m unittest discover -s test -p test_release.py -v
```

Solidity is pinned to **0.8.26**, Cancun EVM, optimizer 200 runs, metadata bytecode hash disabled. There are no production Solidity dependencies, external linked libraries, proxies, upgrade entry points, filesystem permissions or FFI. `forge-std` v1.9.7 is vendored as ordinary source under `lib/forge-std`, with its MIT and Apache licenses. All website application chunks and SDK dependencies needed to serve the site are ordinary files in `web/`; no npm installation or network is needed to build or run unit tests. Foundry, Node 22+ and Python 3 are the local tools used. Normal gameplay still requires internet access to Ethereum RPC endpoints and, for email login, Privy's service.

`python3 tools/sync_abi.py` regenerates the readable browser ABI after a contract build. The frontend test checks it against the artifact so changes cannot silently ship an incompatible interface.

The optional `node test/site.integration.mjs` starts an isolated Anvil chain, deploys the actual artifact with an explicit owner, runs the site release tool against that deployment, and exercises the browser purchase module, timer, commit, settlement, claims and expiry refunds using the vendored ABI encoder/client. It uses no private keys or external RPC. **It could not run in this worker:** Anvil's Unix socket was denied with `Operation not permitted (os error 1)`. Its full execution remains an independent validation item. No real browser, email login, live publishing or production deployment was exercised here.

## Launch parameters

Only one application is deployed:

| Parameter | Value |
| --- | --- |
| Solidity contract | `IMDPot` in `src/IMDPot.sol` |
| Constructor | `constructor(address owner_)`, nonpayable |
| Manifest argument | `$owner` |
| Specified launch owner | `0x34284c5c4c54d5f8e7e14e2d1a3dcd48899928ea` |
| Chain | Ethereum, chain ID 1 |
| Deployment value | 0 ETH |
| Initial game state | Round 1 pending, token unset, entries unavailable until configuration |
| House beneficiary | The specified launch owner, fixed at construction |

The factory can deploy the constructor on an empty chain: it makes no external calls and does not use `msg.sender` or `tx.origin` for ownership. The network's manifest stage, rather than this worker, writes the manifest and deploys the compiled bytecode. No launch token, pool or distributor is created.

## Game rules and assumptions

The existing public site states these rules. They are made constants in the replacement:

| Rule | Value |
| --- | --- |
| Asset and ticket price | ERC20 IMD, 0.1 IMD per ticket, derived from the configured token's decimals |
| Duration | 900 seconds from the first successful purchase; further buys do not extend it |
| Prizes | 40% first ticket, 20% second, 10% third |
| Burn | 10%, transferred to the intentional irreversible `DEAD_ADDRESS` burn destination |
| House | 5%, transferred to the initial launch owner |
| Permanent lock | 15%, retained in this contract without a withdrawal path |
| Maximum purchase | 1,000,000 tickets per call |
| Randomness commitment | Current block number + 3, committed only after the entry deadline |
| Settlement window | Target block + 1 through target block + 256 inclusive |
| Paused active cancellation | 24 hours after the round's scheduled end |
| Loyalty | 1 point per settled ticket, 1 played round per settled round containing that wallet |
| Boost redemption | After 10 settled rounds, 100 points buys +2,500 basis points of ticket weight for the next round entered |
| Boost cap | +10,000 basis points, i.e. 2× total ticket weight |

The 40/20/10 split, 0.1 price, three-block delay, 24-hour paused cancellation, purchase limit and loyalty thresholds were recovered from the site's application and displayed rules. Where the brief only said 70/10/5/15, the site's three prize slots supply the meaning of the 70% share. Token transfers must be exact and non-rebasing. Supported decimals are 1–18; a token with zero decimals cannot represent the specified 0.1 price. An entry transfers IMD, never native ETH. Players also need ETH to pay transaction gas.

### Entries and transitions

1. `Pending`: no timer has started. The first successful `buyTickets(count)` or `buyTicketsForRound(expectedRoundId, count)` starts the 15-minute interval.
2. `Active`: purchases require configuration, an unpaused game, an integer count within the limit, sufficient balance/allowance and `block.timestamp < endTime`. At the exact deadline entries close.
3. `Drawing`: anyone calls `finalizeRound()` after the deadline while unpaused, fixing `drawBlock = block.number + 3`. Entries close and this block cannot be changed, retried or re-rolled.
4. `Finalized`: anyone calls `finalizeRound()` again after the target block and within its 256-block history window. Settlement records winners, credits withdrawable prizes and opens the next pending round. A committed draw can settle even while paused.
5. `Cancelled`: anyone cancels an expired drawing round, or an active round which is paused and at least 24 hours past its scheduled end. Every paid ticket in that round becomes fully refundable. Cancellation opens the next pending round; the pause flag stays in force.

The website uses `buyTicketsForRound` so a transaction reviewed for one round cannot enter a later one. A direct caller can still use the compatible `buyTickets` entry point. Neither function accepts purchases during the draw.

### Winner selection and randomness limits

The seed is `keccak256(abi.encode(blockhash(drawBlock), block.chainid, address(this), roundId))`. The caller, timestamp, current blockhash and mutable caller seed are not inputs. Each prize slot hashes the seed with its slot index and selects an interval in a Fenwick weight tree. Each ticket weighs `10_000 + its wallet's round boost`. A selected ticket's weight is removed before the next selection. Other tickets owned by that wallet remain eligible, so the same wallet can win several slots, up to its purchased ticket count. Purchases and winner lookup are logarithmic in participant count; settlement has at most three slots, without a participant-wide loop.

With one or two tickets, absent prize shares roll into first place. Each non-first share is rounded down in token base units, and all allocation dust goes to first place. Thus prizes, burn, house and lock always sum exactly to the paid pool. Ordinary wallet ticket totals and historical weight totals are unchanged by finalization; cancellation refunds consume the refundable ticket balance.

**Future-blockhash randomness is not unbiased, oracle-verifiable randomness.** Block producers can influence the target hash or censor settlement; a party can also choose to withhold a settlement transaction after observing an unfavorable result. Reorgs remain a risk. The three-block delay prevents committing an already-known hash, not validator influence. Modulo reduction has negligible mathematical bias at practical pool sizes. The requested design deliberately uses no Chainlink subscription, LINK, external random signer or owner-provided seed. Local blockhash mocks test state transitions, not production fairness. A missed settlement window produces refunds rather than predictable replacement randomness. Suitability for funds at risk must be accepted during independent review.

### Funding, claims and fees

The pot is funded only by successful ticket transfers. There is no initial bankroll or externally funded prize promise. Incoming taxed transfers and failed/false-return ERC20 operations revert the entire purchase, including its timer and ticket bookkeeping. ERC20s which return no data are supported.

`claim()` pulls all of the caller's accumulated prizes. A failing or taxed outgoing transfer reverts and preserves that credit. One recipient cannot prevent another from claiming. Claims have no expiry. `refund(roundId)` returns the full ticket cost from a cancelled round, exactly once, without a deadline. Refund failure preserves tickets and the refund obligation. No prize or fee is charged on cancelled rounds.

Settlement tries the burn and house transfers separately. A gas-bounded external self-call isolates each fee attempt, including rollback of tokens that move balances and then return false. Failure emits `FeeTransferDeferred` and retains the amount in `pendingBurn` or `pendingTreasury`; it does not fail the draw. Anyone can retry `flushPendingFees()`. Successful fees emit `FeeTransferred`. Retry cannot pay an already successful share again.

`totalObligations()` includes the current pool, claimable prizes, outstanding refunds, permanent lock and pending fees. It is at most the real token balance; without unsolicited donations it equals that balance. All game-token donations are also unrecoverable. The owner cannot sweep the game token, even surplus tokens. Rebasing, dishonestly reported balances, malicious token upgrades and token-level blocklists can still make a selected asset unusable; the owner must evaluate the actual IMD token before the irreversible setup.

### Loyalty accounting

Points and played rounds accrue only after settlement, once. Accounting is lazy and bounded: a wallet has at most one unresolved participation record. Buying in a later round, redeeming, refunding or calling permissionless `syncPoints(player)` resolves that record. `getPlayer` includes settled-but-unsynced points for an accurate dashboard.

A boost is consumed on the wallet's first purchase in a round, frozen for all its tickets in that round, and does not change ticket price or prize percentages. A redemption while participating queues weight for a later round. Cancelled participation earns no points or played-round credit and restores the used boost, even before refunding. To guarantee restoration without discarding spent points, the cap reserves space for the boost in an unresolved active/drawing round as well as queued boosts. This can temporarily prevent further redemption while a 2× round is unresolved. It is a deliberate clarification beyond the site's brief cap text. Points and boosts are nontransferable accounting entries, with no cash redemption or separate loyalty token.

## Administrative powers

Only the owner can choose the token once, pause/unpause new purchases and new draw commitments, propose an ownership transfer, or rescue an unrelated ERC20. Ownership transfers require the proposed owner's `acceptOwnership()` call. Renunciation is disabled. Transferring ownership does not redirect the fixed house beneficiary.

Pausing cannot stop a committed draw from settling, existing prizes from being claimed, refunds or fee retries. The owner cannot change ticket price, percentages, duration, randomness, a target block, winners or the loyalty rules; withdraw locked IMD; select a replacement game token; or cancel a live valid draw. There is no privileged relayer or EOA-only restriction. Any EIP-1193 wallet, including Privy's embedded wallet or a contract wallet, can approve IMD and enter.

The owner is trusted to configure the correct asset, manage pauses and retain access to the owner wallet. The fee beneficiary's token-level ability to receive payments is outside the game. A malicious or lost owner can prevent configuration or new commitments, but the paused-active timeout allows existing active-round participants to recover their funds.

## After launch

These are operational steps for the launch service, owner and existing site operator. They are not worker transactions.

1. **Launch service:** independently review and deploy the single fresh `IMDPot` artifact on Ethereum with constructor argument `$owner`. Record the actual address, deployment transaction and deployment block. Verify the source with the exact pinned compiler/settings. Keep the old contract and its claims/refunds accessible separately; nothing migrates automatically.
2. **Site operator:** run the release command below using the confirmed address/block, then publish the resulting `web-release/` contents to the existing site's origin. The tool refuses the old contract, wrong chain, wrong runtime, wrong deployment block and wrong house beneficiary. It needs a trusted RPC that can read code at the deployment block and its preceding block. Runtime must match this build byte for byte. It does not sign transactions or read wallet configuration.
3. **Owner:** connect the specified owner wallet to the existing site's owner panel and call `setToken(address)` once. The address shown by the existing site is `0xd34a99bc0f67ae1bbd63c660e6d0b0dd03e263b7`. A read-only Ethereum check during this task returned nonempty code, `symbol() = IMD` and `decimals() = 18`. Verify this is the intended project's token using its authoritative deployment records before confirming. The setter emits `TokenSet` and derives the 0.1 IMD price. Before it succeeds, purchases/finalization revert `TokenNotConfigured`. It requires no oracle or further initialization. This address is a public-site setting, not a constructor dependency or invented substitute.
4. **Privy app administrator:** retain the site's existing public app ID `cmve43hs901uf0gl1dqj33sqc` in `site-config.json` and its existing domain allowlist. This is a public client identifier, not a secret. Test email login on the published origin with the intended embedded wallet. The contract needs no Privy app ID, backend signer or privileged wallet list. Injected/browser wallets remain available if Privy is unavailable.
5. **Game operator or players:** monitor each active round, submit the first finalize after 900 seconds, then the second after the target block and no later than target + 256. These actions are permissionless but somebody must pay ETH gas; the contract cannot run itself. The UI shows the block window and supports both calls. Consider a keeper operated by the launch owner; no keeper is supplied or funded by the contributor network. Track deferred fees and retry them. Cancel expired rounds and direct participants to refunds if a draw was missed.
6. **Site operator:** smoke-test configuration, wallet connection, exact approval plus entry, timer, both draw calls, claims, owner pause/resume, and refund tools. Serve `.mjs` with a JavaScript MIME type. Publish HTML and `deployment.json` with revalidation/no-store caching, and publish the changed entry chunk with cache revalidation. All preserved chunks use the new `assets-future-v1/` path so cached modules from the old deployment cannot mix with the new game. Bump that directory version if changing those chunks again. Keep dependent assets while sessions from the previous site version finish. The code itself requests deployment settings without cache and checks chain/runtime before every transaction.

After `forge build` and ABI synchronization:

```text
python3 tools/build_site.py --address <CONFIRMED_NEW_ADDRESS> --block <ACTUAL_DEPLOYMENT_BLOCK> --rpc <TRUSTED_ETHEREUM_RPC>
```

The angle-bracket terms are required inputs from the future confirmed handoff, not values to publish. The tool writes a new `web-release/` directory and refuses to overwrite an existing release. `web/` deliberately has no `deployment.json`; serving it without a handoff shows an unavailable message and allows no purchases. No live configuration falls back to the previous deployment. `web/config-schema.mjs` also rejects the previous address, unset addresses and malformed settings. Do not manually invent an address to make the page appear ready.

The public site snapshot and pre-change SHA-256 inventory (before moving `assets/` to `assets-future-v1/`) are recorded in `docs/site-capture.json`. The retained chunks preserve its layout, wallet chooser, transaction confirmations, activity history, player dashboard, owner panel and Privy session. The small readable `.mjs` modules contain the changed deployment checks, timer/draw boundaries and reviewed-purchase logic. The ABI is generated from this contract rather than the old VRF interface. No site-account credentials were available or needed for producing these files; publishing the reviewed release is the existing site's operator's responsibility.

## Validation and remaining review

Solidity success/failure tests cover constructor ownership through a factory, unset/set configuration, prices/decimals, invalid and late entries, duplicate purchases, the three-block commitment, unavailable/expired hashes, exact settlement-window edges, draw cancellation rules, all prize shares and dust, ticket selection without replacement, pull payouts, failed refunds, blocked and false-return fees, taxed/no-return tokens, contract-wallet entry and claim reentrancy, loyalty thresholds/caps/restoration and stale-round purchase protection. The Fenwick tree is fuzzed against an independent linear interval oracle, including appending after updates and zero-weight nodes. Stateful invariants exercise interleaved purchases, pauses, settlements, claims, refunds and loyalty sync/redemption, checking conservation and historical liabilities. Tests are isolated and use no environment reads, forks or shared settings.

Frontend tests cover configuration refusal, runtime verification, timer and block boundaries, input limits, exact approvals, purchase failures and approval-time round changes. Python release tests check successful output and refusal paths. `docs/SECURITY.md` records the implementation review and trust limits. These checks are not an independent security audit. Independent adversarial review, the full Anvil/browser test, confirmed factory deployment, website publication and real Privy login remain release responsibilities.
