# Source Audit — Karak K2 L1 custody (shutdown era)

Pinned observation block: **26347966** (`0x19209be`), hash
`0x9a1b6259fc3e849d539defa91a0aa6b460fdf28fb5d6c774d7e7b767d08d6e0d`, ts 1793815509.
Chain: Ethereum mainnet (chainId 1). All reads are read-only; all state-changing
results were produced on a local anvil fork at the pin block (labeled SYNTH).

## Contract system (all addresses verified live at pin block)

| Role | Proxy | Impl (EIP-1967 `0x360894…`) | Version / note |
|---|---|---|---|
| OptimismPortal (ETH escrow + ETH claims) | `0xeeCE9CD7Abd1CC84d9dfc7493e7e68079E47eA73` | `0xB1762246367681e5b335968950e8A17b0c56021D` | `version() = "2.3.0"` — shutdown merkle-claim impl |
| L1StandardBridge (ERC-20 escrow + token claims) | `0xBa61f25DD9F2D5f02d01B1C2c1c5F0b14C4B48a3` | `0xf44b55e152e872ff5cbd3d9f3bd732f67d5b366a` | `version = "2.3.0"` — shutdown merkle-claim impl |
| L1CrossDomainMessenger | `0x9BffA66A8fcaAd7Ac9eA7C7d4b9a6fc46777022d` | impl slot `0x0` | messenger path dead (see below) |
| L1ERC721Bridge | `0x952851ceCB07705a5bb483c1cE080F97E1E7491e` | — | custody irrelevant (no NFT escrow observed) |
| L2OutputOracle | `0x0A23342520Aa8Ca963c4201801f4D3E95e731637` | `0x394317b191f5c7a371e74594776b1efdc33d10d6` | legacy withdrawal path hard-reverts in portal |
| SystemConfig | `0x622333688CC1878C7Ff4205c89Bde051798788A7` | `0x01d5303f326b992845eef2782d4c9a7c6dde4470` | source of address registry above |
| ETHYieldManager | `0x98078db053902644191f93988341E31289E1C8FE` | `0x7b646dec285da35ad81c6e330435b1f92d8799ab` | residual custody (~12.96 stETH + 0.0001 WETH + 0.0006 ETH) |
| Guardian (Safe) | `0x28A227d4faF0f4f75897438E24C43EF1CDABb920` | — | `pause`/`unpause`/`setMerkleRoot{ETH}`/`recover{ETH,Tokens}` |
| ProxyAdmin | `0x1612f868eba1cea65ee66bf4a7c75001b0d4065c` | — | admin slot `0xb53127…` for OP-style proxies |

Registry provenance: `SYSTEM_CONFIG()`/`L2_ORACLE()`/`GUARDIAN()`/`version()` on the
portal at pin block; `l1StandardBridge()`/`l1CrossDomainMessenger()`/
`l1ERC721Bridge()`/`l2OutputOracle()`/`optimismPortal()`/`batcherHash()` on
SystemConfig at pin block. All raw calls preserved in `local-replay/` artifacts.

## Verified-source status

- `0xB1762246…` (portal impl): verified source via Routescan/Etherscan-compatible
  API (`ContractName: OptimismPortal`, solc `v0.8.15+commit.e14f2714`, evm london,
  194,013-byte standard-JSON input) and **Sourcify runtime match**
  (`matchId 51233572`, verified 2026-09-18). Extracted main source:
  `src/src_OptimismPortal.sol`.
- `0xf44b55e1…` (L1SB impl): verified source (`ContractName: L1StandardBridge`,
  210,066-byte stdJSON). Extracted: `src/src_L1StandardBridge.sol`.

## Shutdown-era ABI surface (OptimismPortal v2.3.0)

Disabled paths (hard revert strings, confirmed live by `eth_call` on fork):

- `depositTransaction(…)` and `receive()` → `"OptimismPortal: deposits disabled"`
- `proveWithdrawalTransaction(…)` / `finalizeWithdrawalTransaction(…)` →
  `"OptimismPortal: traditional withdrawal path disabled, use the new claim function"`

Active exits:

- `claimETH(uint256 _amount, bytes32[] _proof)` — leaf =
  `keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _amount))))`;
  OZ `MerkleProof.verify` vs `merkleRootETH`; cumulative `claimedETH[msg.sender]`
  (`_amount` is cumulative entitlement, payout = `_amount − claimed`); pays
  `msg.sender` via `SafeCall.call`. `require(!paused)`, `_amount > 0`,
  `claimable <= address(this).balance` (first-come-first-served on insolvency).
- `recoverETH(address)` — `guardian` only + `paused` +
  `block.timestamp >= RECOVERY_TIMESTAMP (1820707200 = 2027-09-12)` → sweeps the
  **entire** balance to `_recipient`.
- `setMerkleRootETH(bytes32)` — guardian only, any nonzero root, replaces at will.
- `pause()`/`unpause()` — guardian only. `donateETH()` — payable no-op (donations
  merge into the claimable escrow).

L1StandardBridge v2.3.0 mirrors this for ERC-20:

- `claimTokens(address[] _tokens, uint256[] _amounts, bytes32[] _proof)` — leaf =
  `keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _tokens, _amounts))))`;
  separate `merkleRoot`; per-token cumulative `claimedTokens[msg.sender][token]`;
  O(n²) duplicate-token guard; `safeTransfer(msg.sender, delta)` per token.
- `setMerkleRoot(bytes32)`, `recoverTokens(recipient, tokens[])`,
  `sweepETH()` — all `onlyGuardian` (guardian read live from portal); recover
  additionally requires portal `paused` + `RECOVERY_TIMESTAMP`.

## Initialization / upgrade state

- Portal proxy slot0 `_initialized = 3` (= `Constants.INITIALIZER`); live
  `initialize(0,0,0,false)` call **reverts** "contract is already initialized".
  The initialize-takeover path is closed.
- Legacy impl history: prior portal impl `0x3fe449Ef47228F03f979F9D955196494243cdf7E`
  (v1.10.0 pre-shutdown). Shutdown upgrade tx `0x59515cbe…` (multisig), root-set +
  unpause tx `0x2080dbdf…` (2026-09-15/16).
- L1XDM impl slot reads `0x0` → messenger cannot relay; both bridge deposit
  paths and any messenger-dependent finalization are inert at pin block.

## Blockers / not-yet-verified

- Guardian Safe owner set + threshold (Safe proxy — needs getOwners/getThreshold
  reads; recorded as TODO in unresolved list of prior audit).
- ETHYieldManager impl `0x7b646dec…` source not yet retrieved (minor custody).
- Off-chain merkle trees for `merkleRootETH` and `merkleRoot` are **not
  published** — leaf/proof availability cannot be verified on-chain.
- Full historical fund-flow ledger (all deposits/withdrawals pre-shutdown) not
  reconstructed; scope here is the shutdown-era custody + claim mechanism.
