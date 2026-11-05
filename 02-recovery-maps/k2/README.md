# K2 Shutdown — Preliminary Recovery Map

**Classification: U — Insufficient evidence.**

| Question | Current status |
|---|---|
| Confirmed K2 L1 escrow and exit-claim contract addresses | NOT_VERIFIED |
| Contract source and runtime bytecode match | NOT_VERIFIED |
| Historical gross deposits and withdrawals | NOT_VERIFIED |
| Administrator and internal custody transfers | NOT_VERIFIED |
| Residual custody balances and claimant obligations | NOT_VERIFIED |
| Authorized claimant recovery simulation | NOT_RUN |
| Non-claimant authorization tests | NOT_RUN |
| Independent reviewer verdict | PENDING |

**Accounting invariant:** Opening assets + external deposits − genuine external payouts = ending assets, adjusted only for separately evidenced rebasing, burns, mints, migrations and fees. Do not count internal custody movements as system outflows.

**Scope:** Karak K2 bridge and shutdown mechanisms, not automatically the Karak Restaking Core/Vault code.

**Safety:** No production asset movement, unauthorized claims, or publication of sensitive exploit instructions.

[Recovery Maps](../)
