# ClawPunks Smart Contract

Fully onchain 20×20 pixel art NFT. Art design matches `preview/generate_grid_svg.py`.

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## Deploy

```bash
# Set PRIVATE_KEY or DEPLOYER_PRIVATE_KEY
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

## Features

- **20×20 grid** — Same pixel map as generate_grid_svg.py (green, yellow, pink, red, bg)
- **5 trait types** — Body, eyes, green (appendages), pink (torso), background
- **7 colors each** — 7^5 = 16,807 unique combinations for 10k supply
- **Deterministic traits** — Derived from tokenId (no per-token storage)
- **Premint only** — Owner premints; airdrop via `transferFrom` from backend

## Pixel Map

| Code | Role   | Trait   |
|------|--------|---------|
| 0    | Background | bg     |
| 1    | Appendages | green  |
| 2    | Eyes       | yellow |
| 3    | Torso      | pink   |
| 4    | Body       | red    |
