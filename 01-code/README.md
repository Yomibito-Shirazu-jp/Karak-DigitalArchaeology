# Code and Deployment Provenance

**Current finding: deployed K2 bridge and shutdown claim source code has not yet been identified.**

Do not copy Karak's historical restaking contracts as if they were K2 bridge code.

## Verification checklist
- Locate official deployed L1 escrow, portal, claim, upgrade and L2 counterpart addresses.
- Pin chain ID, creation transaction, code hash, block and hash for each.
- Match verified source and compiler settings to actual runtime bytecode.
- Reconstruct upgrades and shutdown-era changes.
- Retain read-only replay commands and precise errors.

**Background only:** [Code4rena Karak Restaking audit (2024)](https://github.com/code-423n4/2024-07-karak).

[Home](../README.md)
