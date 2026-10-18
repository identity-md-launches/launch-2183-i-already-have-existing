# Implementation review

This is the implementation author's review, not a separate contributor's audit. The release stage must still obtain independent adversarial review before accepting player funds.

## Custody and accounting

All IMD exits are either a credit-backed claim, a cancelled-ticket refund, a fixed fee or the explicit burn. There is no game-token rescue or arbitrary approval path. The unrelated-token rescue cannot select the configured game token. Constructor storage assigns both ownership and the fixed treasury to the explicit launch owner, not the factory. Privileges cannot be initialized again.

The accounting partition is:

```text
current round pool
+ totalClaimable
+ totalRefundable
+ totalLocked
+ pendingBurn
+ pendingTreasury
= totalObligations
<= token.balanceOf(IMDPot)
```

The equality version holds for exact-transfer assets absent unsolicited donations. The invariant suite also independently sums claims by wallet, refundable tickets across historical cancelled rounds, locked shares across finalized rounds, and all token balances including the house and burn destination.

Rounding cannot lose liabilities: all non-first allocations floor, and first prize gets the remaining pool. Missing second/third winning tickets increase first prize. Ticket selection removes one ticket's weight, not a whole wallet. The tree's dynamic append computes the previous interval prefix correctly, and an independent linear oracle checks its boundaries after updates, growth and removals. No participant-wide iteration occurs in transactions.

## External calls and reentrancy

Every asset-moving or gameplay-changing entry point uses a persistent reentrancy guard. Token configuration and owner changes that could be reached during a malicious callback are guarded too. Renunciation only reverts. Read-only getters have no external calls except the frontend's own independent token reads; `getPlayer` itself is entirely internal state.

Purchases update round/ticket state before transferFrom; transfer failure reverts those effects atomically. Claims and refunds consume their liability before transfer, and roll back on failure. Incoming transfers measure the pot's balance increase. Outgoing transfers measure both the pot's decrease and recipient's increase. Tokens returning no data work; false or malformed returns fail. A token may still lie in balanceOf or change behavior through its own upgrade controls, so exact-balance checks cannot make arbitrary assets trustworthy.

Fees are attempted only after settlement bookkeeping and current-round advancement. Self-call isolation rolls back each failed attempt, including ERC20s that transfer then return false or tax the transfer. Each attempt is limited to 150,000 gas. The exposed `transferFee` is callable only by the contract itself; it offers no external drain primitive. Fee callbacks cannot reenter gameplay, fee flushing, claims or refunds. Any gas-exhausted transaction itself can still revert atomically; callers must budget enough gas for settlement and the two optional attempts. The UI simulates transactions before submitting.

Concrete regressions include a false-after-moving token paying zero fees but retaining both full obligations, a blocked prize recipient retaining its claim while another winner claims, a taxed claim preserving the full credit, and contract-wallet callbacks failing reentry with `ReentrancyGuardReentrantCall` while their outer transaction succeeds.

## Time, randomness and liveness

Deadline equality rejects entries. Commitment requires an ended active round and unpaused state. The target is always three blocks ahead of the commitment, stored once. Subsequent calls cannot select a later block or refresh the deadline. Target equality is too early to settle; target + 256 is valid; target + 257 is expired. A zero hash is rejected, not used as fallback entropy. The expired path refunds in full and does not award points or fees.

There is no privileged settlement callback or external randomness source. Winner seeds bind chain ID, contract address and round ID, but the blockhash is inherently influenceable by block producers. Censorship/withholding can cause refunds. Builders can also affect timestamps near entry deadlines. Neither the three-block delay nor tests remove these limitations. The requested randomness design needs economic risk acceptance rather than a claim of cryptographic fairness.

No onchain timer causes an automatic call. Operators/players must act within the hash window. A lost or malicious owner can pause purchases and commitments. An active paused round can be cancelled by anyone after the 24-hour timeout. Once committed, a pause cannot stop settlement or change the target. Claim/refund/flush paths remain available while paused.

## Loyalty and administration

A wallet has one unresolved participation record because there is a single serial active/drawing round. Before entering another round it resolves the old record, avoiding an unbounded history loop. `getPlayer` projects that same update without mutation; permissionless sync can apply it once. Cancellation never gives settled points or rounds, and restores its consumed boost. The redemption cap accounts for the live boost which might have to be restored, preventing a cancellation from burning points spent on queued multipliers.

There are no signed claim messages, application signatures, backend signer keys, relayer permissions or tx.origin checks. Wallet addresses own tickets and rewards, including contract wallets. A change of Privy login/wallet produces a different player identity; the contract cannot merge accounts. Owners transfer control in two steps and cannot renounce or upgrade. The fixed treasury stays the launch owner after an ownership handover; this distinction is visible in the owner panel and documented.

## Website boundary

The site requires a fresh-address handoff. The release tool verifies chain ID, latest runtime, code at the claimed deployment block, absent code in its preceding block and the fixed treasury. The browser verifies chain and runtime hash before reads used for play and before every wallet submission. It checks wallet account/chain, simulates the call, waits for a successful receipt and detects replaced/cancelled transactions. Approval does not itself enter the round. The reviewed-round entry call closes the remaining race between approval/review and transaction inclusion.

These checks trust the RPC endpoint and the integrity of the published website/configuration. They do not verify an RPC's honesty. The pre-existing published SDK chunks were retained rather than reconstructed from missing development sources; their upstream dependency audit is outside this review. The preserved Privy ID was read from the existing site's public configuration and is not a secret. Email authentication, domain allowlisting and wallet recovery remain Privy/app administrator responsibilities.

## Evidence and limits

The delivered test suites provide deterministic examples, fuzzing with the assignment seed and stateful invariants. The release tool and frontend modules have offline unit tests. Foundry lint still reports heuristic timestamp/external-call warnings; the necessary timestamp use and guarded token interactions are analyzed above rather than treated as randomness inputs or unprotected calls. No Slither/Mythril or independent audit was performed. A separate Anvil integration attempt was denied socket creation by the worker OS (`Operation not permitted`, error 1); no end-to-end Anvil/browser success is claimed. Source verification, factory simulation, actual launch, live publishing and production login belong to the later release process.
