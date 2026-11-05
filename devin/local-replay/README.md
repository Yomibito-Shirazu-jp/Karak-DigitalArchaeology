# Local replay (read-only + local fork)

```
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/<KEY> \
      --fork-block-number 26347966 --port 8545
python auth_matrix_full.py    # -> withdrawal-matrix.json, 24/24 PASS expected
```

Pin hash `0x9a1b6259fc3e849d539defa91a0aa6b460fdf28fb5d6c774d7e7b767d08d6e0d`.
Dependencies: foundry (anvil/cast), python3 stdlib. No signing, no secrets,
no mainnet transactions. Guardian impersonation only on the local fork —
results labeled SYNTH in `withdrawal-matrix.json`.
