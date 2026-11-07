# Authorization Invariants — tested vs K2 shutdown impl (v2.3.0)

Method: `eth_call`/live reads at pin block 26347966 for negative boundary tests;
`anvil --fork-block-number 26347966` for state-changing tests. Guardian-impersonation
results are labeled **SYNTH** — they demonstrate mechanism semantics, never real
key possession. Results file: `local-replay/withdrawal-matrix.json` (24/24 PASS).
Driver: `local-replay/auth_matrix_full.py` (stdlib + `cast` + anvil only).

## Invariants vs evidence

| # | Invariant | Result | Evidence |
|---|---|---|---|
| 1 | Approved claimant receives ≤ verified entitlement | **HOLDS** | SYNTH: leaf(VIC,100e18) → claimETH pays exactly 100.00 ETH; escrow delta = −100.00; claimable capped by `_amount − claimedETH` |
| 2 | Unrelated claimant cannot take another's entitlement | **HOLDS** | NEG: attacker `claimETH(1e18,[])` → "invalid proof". SYNTH: attacker reusing victim's `(amount,proof)` → "invalid proof" (leaf binds `msg.sender`) |
| 3 | Claim cannot execute twice | **HOLDS** | SYNTH: second `claimETH(100e18,[])` → "nothing to claim" (`_amount > claimed` fails) |
| 4 | Settlement meaning cannot shift (chain/token/recipient) | **HOLDS at contract level** | Payout hard-bound to `msg.sender` — no recipient param. ETH leaf schema `H(H(addr,amount))` vs token leaf `H(H(addr,tokens[],amounts[]))` cannot collide. No chainId/domain in leaf: replay across *distinct escrow contracts sharing one root* would pay twice — only exploitable if guardian reuses a root across contracts; per-contract replay impossible (cumulative claimed accounting) |
| 5 | Successful withdrawal reduces liability | **HOLDS** | `claimedETH[s]` set to `_amount` before SafeCall (CEI); SYNTH balance deltas reconcile exactly |
| 6 | Assets/obligations reconcile | **PARTIAL** | Escrow deltas match payouts exactly in replay; total obligations unknowable (tree unpublished); FCFS `claimable <= balance` means late claimants revert if escrow undercollateralized |

## Additional authorization facts (NEG, unimpersonated)

- `setMerkleRootETH`, `setMerkleRoot`, `pause`, `unpause`, `recoverETH`,
  `recoverTokens`, `sweepETH` — all revert for non-guardian ("only guardian").
- `initialize` on live portal proxy reverts (already initialized, slot0=3).
- `depositTransaction`, `receive`, `proveWithdrawalTransaction`,
  `finalizeWithdrawalTransaction` — hard-disabled reverts.
- `claimTokens` duplicate-token and length-mismatch reverts verified.

## Admin powers (documented, not vulnerabilities)

1. Guardian may replace `merkleRoot{ETH}` at any time → can invalidate existing
   leaves and mint new entitlements for any address. This is the root-of-trust for
   ALL claimant obligations.
2. `recoverETH`/`recoverTokens` after **2027-09-12** while paused sweeps 100% of
   escrow — including unclaimed entitlements. Claimants have a hard deadline.
3. `pause` can freeze claims indefinitely (liveness only; funds cannot leave
   through user paths while paused).

## Security verdict inputs

- Attacker-controlled input to all claim paths is `(amount, proof)` /
  `(tokens[], amounts[], proof)`; every value is bound into the leaf with
  `msg.sender`. No acceptance-with-different-meaning path found.
- No unauthorized withdrawal path reproduced. → `NO_VULNERABILITY_CONFIRMED`
  for the audited surface (see `results.json`); bounty scope separately
  `BOUNTY_SCOPE_NOT_CONFIRMED` (OpenGDP program exists, K2 coverage unverified).
