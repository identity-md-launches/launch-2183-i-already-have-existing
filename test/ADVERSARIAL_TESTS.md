# Additional IMDPot tests

These suites extend the accepted tests without changing the application, website,
dependencies or Foundry configuration. They use only the vendored forge-std and local
ERC20 stand-ins. No RPC, environment mutation, FFI, wallet keys or deployment is needed.

Run from the repository root:

```sh
forge build
FOUNDRY_FUZZ_SEED=0xcbd2a37cf5739138e3a0b29daa90709680ffd9f670aa9e75ae42c8ba98a991ee forge test
```

The nine additional parameterized tests each carry an inline 1,000-run setting.
The ledger invariant suite carries inline settings for 256 sequences of 128 calls,
with unexpected handler reverts treated as failures.

| Suite | Additional checks |
| --- | --- |
| `IMDPot.boundaries.t.sol` | Maximum and overflowing ticket counts, exact deadline boundaries on both purchase APIs, complete rollback of failed boosted entry, delayed refunds across several rounds while paused, every owner-only entry point, superseded ownership nominees, actual fee routing after ownership transfer, stale purchase protection after cancellation. |
| `IMDPot.token-failures.t.sol` | False, short, long, non-boolean and reverting ERC20 responses after balances move; no-return compatibility; sender surcharges and recipient taxes; true-return transfers that move no value; isolated gas-exhausting fee recipients; accumulated deferred fees; rescue validation; reentrancy into 15 entry points from a token that is also the owner. |
| `IMDPot.selection.t.sol` | An independent linear interval oracle for weighted selection without replacement, including different wallet boosts and updates before tree growth; equivalent bulk/split purchases; finalizer, timestamp and current prevrandao cannot change a committed draw's result. |
| `IMDPot.model.invariant.t.sol` | Random interleavings of purchases, commitment, settlement, cancellation, claims, refunds, redemptions, synchronization, pause changes, time/block advances, fee blocklists, no-return tokens, donations and failed payments. |

## Ledger properties

The handler maintains a ledger from successful inputs and validated round allocations.
It checks the following after every random call:

- Real custody equals deposits plus donations minus claims, refunds and paid fees.
  Obligations exclude donation surplus and match each independently tracked liability.
- Every actor's token balance and claim credit matches that actor's ledger. The total
  token amount remains accounted for across players, pot, treasury and burn destination.
- An eager history of settled tickets, played rounds, point spending, queued boosts
  and cancelled boost restoration matches the contract's lazy player projection.
- Current-round tickets, participant order, weights, timer and draw commitment match
  successful purchases and state transitions. Terminal round records cannot change.
- Winners own enough distinct tickets for their awarded slots. The separate selection
  suite checks the exact winning intervals using a linear oracle instead of a Fenwick tree.

Valid operations are required to succeed. Invalid operations check their precise error;
the handler does not catch and ignore unexpected failures. Ten real rounds in setup make
all four actors eligible for loyalty redemption before random exploration starts. A
deterministic handler trace exercises boost restoration, failed payments, no-return
donations, deferred fees and repeated/delayed refunds.

At the end of every random sequence, `afterInvariant` clears token fee blocklists,
resolves the open round, flushes fees and withdraws every available prize and refund.
Only permanent locks and donations may remain. This checks withdrawal liveness as well
as passive accounting.

## Scope and limits

No implementation defect was reproduced by these additional suites. A passing test is
not evidence that future-blockhash randomness is unbiased: block producers, censorship
and reorgs are outside the simulated properties. Mock assets exercise transfer semantics;
they cannot establish the identity or upgrade behavior of a production token. Actual
factory deployment, the production token, website publication and Privy login still need
their release checks. No live deployment or website change is claimed by this tests task.
