# Recovery Map — Karak K2 shutdown custody

**Classification: B — recovery route exists and is live, but requires the
administrator-published Merkle proof (tree not public).**

Pin: L1 block 26347966 / `0x9a1b6259…e0d`.

## Asset locations (verified at pin block)

| Contract | Asset | Amount |
|---|---|---|
| OptimismPortal `0xeeCE…EA73` | ETH | 1,846.4981969416722 |
| L1StandardBridge `0xBa61…48a3` | USDC | 156,769.046684 |
| L1StandardBridge `0xBa61…48a3` | rswETH | 166.553334246815451011 wei |

## Claimed so far

300 `ETHClaimed` events, 300 unique claimers, **29.723958719929808 ETH** paid out
since shutdown mechanism activation — reconciles the ~29.5 ETH gap vs L2BEAT's
1,876 ETH figure.

## Recovery conditions

| Route | Authority needed | Status |
|---|---|---|
| `claimETH(amount, proof)` | valid leaf in `merkleRootETH` for caller | **LIVE** — unpaused, root set |
| `claimTokens(t, a, proof)` | valid leaf in L1SB `merkleRoot` for caller | **LIVE** — unpaused, root state per `merkleRoot()` |
| `recoverETH` / `recoverTokens` | guardian + paused + ts ≥ 2027-09-12 | dormant until deadline |
| legacy `prove/finalizeWithdrawal` | — | hard-disabled |
| deposits / messenger | — | hard-disabled / impl `0x0` |

## Claimant categories

- Leaf holders (pre-Dec-2025 bridgers who unstaked per Discord notice; entitlements
  computed off-chain by K2/OpenGDP).
- Unstaked K2 users whose balances were snapshotted into the tree.
- Administrator (guardian Safe) — recovery sweep after 2027-09-12.

## Legitimate recovery path (public-safe)

1. Obtain your leaf amount + proof from the K2 claim UI (k2bridge.karak.network)
   or directly from OpenGDP support — the tree is not on-chain.
2. Call `claimETH(amount, proof)` on `0xeeCE…EA73` (ETH) and/or
   `claimTokens(tokens[], amounts[], proof)` on `0xBa61…48a3` (ERC-20).
   Payout is bound to `msg.sender`; contracts and EOAs both work.
3. Entitlements are cumulative: re-claiming pays only the delta vs
   `claimedETH`/`claimedTokens` already taken.
4. Deadline risk: after **2027-09-12**, if the guardian pauses, all remaining
   escrow can be swept via `recoverETH`/`recoverTokens`.

## Administrator dependencies

- Guardian Safe `0x28A2…B920` controls: merkle roots, pause, recovery sweep.
- Claim availability depends on unpublished off-chain tree — proof cannot be
  derived on-chain.
- FCFS: if total leaf entitlements exceed escrow, late claimants revert
  ("insufficient balance").

## Unresolved accounting differences

- Total entitlement sum (tree leaves) — unknown, off-chain.
- Whether the 166.55 rswETH + 156,769 USDC in L1SB is fully covered by
  `merkleRoot` leaves — unknown without tree.
- ~~EYM stETH~~ **correction 2026-11-07**: `0x98078db…` belongs to **Blast**, not K2 — removed.

## Publication-safety

- No exploitable path found to withhold. Boundary tests are public-safe
  (all revert evidence). Bounty verdict: `BOUNTY_SCOPE_NOT_CONFIRMED` —
  OpenGDP self-hosted program exists, K2 scope unconfirmed; no eligible vuln
  reproduced.
