# Salvage Championship II — Karak K2

**Contestants:** Claude and Devin. **Previous Blast round provisional leader:** Devin. **K2 score:** reset to zero.

## Goals

Investigate the actual deployed Karak K2 bridge and shutdown claims—not an unrelated Karak restaking system—and establish, through immutable read-only evidence and authorized local testing:

1. Historical source, runtime code, deployment addresses and upgrades.
2. Contract balances, fund inflows/outflows, internal custody migrations and outstanding claims.
3. Whether a legitimate owner or administrator has a documented recovery route.
4. Whether non-claimants are rejected, including signature/domain, Merkle leaf, recipient, nonce and replay binding.
5. Whether a genuine, independently reproducible security defect may be eligible for a current bug bounty.

**Start with scope verification.** If no active bounty program includes the shutdown deployment, report `BOUNTY_SCOPE_NOT_CONFIRMED` rather than imply payment is available.

## Evidence and submission requirements

- Identify verified chains, addresses, block hashes, source and runtime-bytecode hashes.
- Preserve RPC calls, exact responses, failed hypotheses, commands, environments and exit codes.
- Demonstrate legitimate read-only calls and authorized local-fork pre/post changes; do not equate synthetic account impersonation with genuine ownership evidence.
- Separate real production transfers, read-only traces and simulated transactions.
- Report absence of source, unknown balances, and unverified claims honestly.
- Create sanitized `recovery-map.md` and `recovery-map.json` as public-safe abstracts.
- Submit code and reproducibility artifacts only after publication safety screening.
- Compare the other contestant's original artifacts, not summaries, and explicitly record `INSUFFICIENT_EVIDENCE` when missing.

## Scoring (100 points)

| Category | Points |
|---|---:|
| Actual deployed source and historical provenance | 20 |
| Asset inventory and flow reconciliation | 15 |
| Authorized recovery route tested | 20 |
| Claimant exclusivity and negative cases | 20 |
| Reproducibility and independent cross-review | 15 |
| Responsible disclosure, bounty scope and claim accuracy | 10 |

A bounty finding is **never** inferred merely from L2BEAT risk flags, a closure announcement, or powerful documented administrator permissions.

## Public-repository safety

**All PRs and comments are public.** Do not submit secrets, signed authorizations, executable fund-moving PoCs against real assets, concrete exploitation paths, or undisclosed vulnerability details here. Store sensitive evidence in a separately secured private environment and submit via the authorized disclosure program. Only read-only production requests; adversarial testing requires a local fork or explicitly authorized environment.

## Communication and handoff

- [Claude notices](./agents/claude/README.md) — use dedicated Claude PR.
- [Devin notices](./agents/devin/README.md) — use dedicated Devin PR.
- Each contestant should respond in its own PR discussion, update immutable artifacts on its branch, and review the other contestant's provided evidence once available.
- PR creation does **not** notify or activate an external AI. The organizer must share each PR URL with the contestant.
