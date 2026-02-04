# ClawPunks: Fully Onchain NFT Collection — Plan

**Spec**: 10,000 supply. Base character = Claw (red lobster with prominent claws, antennae, segmented body, tail fan). Admin premint, airdrop to Claw agents via backend API. Ethereum Sepolia (test) + mainnet (prod).

### Current Implementation (as of Feb 2025)

- **Grid**: 20×20 pixels (from `generate_grid_svg.py`)
- **Pixel map**: 0=bg, 1=claw, 2=eyes, 3=torso, 4=body
- **7-color palette**: black, white, red, yellow, teal, blue, violet
- **5 traits**: Background, Body, Torso, Claw, Eyes — each independent (can match or differ). 7⁵ = 16,807 unique combinations

---

## How CryptoPunks Art Works

CryptoPunks uses **24x24 pixel composite images** built from layered traits:

- **Base layer**: Face type (required) — skin color, face shape
- **Trait layers**: Accessories (optional) — hairstyles, eyewear, beards, hats
- Each trait is a 24x24 PNG layer; layers are composited (later layers overwrite pixels)
- Onchain: Larva Labs stores pre-computed SVGs in a data contract (~650KB compressed for 10k punks)
- `punkSVG(tokenId)` returns the full SVG string

---

## EthereumNorthStar Pattern (Reference)

Uses **procedural SVG** built entirely in Solidity:

1. **Token data**: Store per-token parameters in mappings
2. **SVG construction**: Build SVG string with `abi.encodePacked()` from those parameters
3. **Base64 encoding**: `Base64.encode(bytes(svgImage))` for the image
4. **JSON metadata**: Embed as `"image": "data:image/svg+xml;base64,{imageBase64}"`
5. **tokenURI**: Return `data:application/json;base64,{json}` (fully onchain, no external URLs)

---

## ClawPunks Architecture

Combine **CryptoPunks-style trait composite** + **EthereumNorthStar-style procedural SVG**.

### Approach: Pixel Grid + Trait Colors

Store **trait IDs** (color palette indices) per token. The contract holds a **24×24 pixel map** (compact string or packed data) and a **color palette**. At `tokenURI()` time, render each pixel as an SVG `<rect>`, using the palette to resolve colors. Same pattern as CryptoPunks: composite = base pixel map + color lookup.

### Base Character: Claw (Pixel Lobster)

The base Claw character is a **24×24 pixel art lobster** (CryptoPunks style):

- **Resolution**: 24×24 pixels — each pixel = one `<rect>` in SVG
- **Claws**: Large, prominent claws raised and spread, forming a heart-like shape at top
- **Eyes**: Two small black square pixels
- **Antennae**: Four thin spiky antennae (2 long, 2 shorter) extending from head
- **Body**: Carapace + segmented abdomen with yellow/golden-orange belly band
- **Tail**: Fan-shaped with dark blue/navy horizontal bands
- **Coloration**: Red body, darker red claws/shading, yellow belly, navy tail bands, brown antennae

Traits can vary: body/claw/belly/tail colors; accessory overlays (hats, bow ties) as additional pixel layers.

---

## Art Design Guide

### Coordinate System

- **Grid**: 24×24 pixels (like CryptoPunks)
- **viewBox**: `0 0 24 24` or `0 0 240 240` (scale 10× for display)
- **Display size**: 240×240 or 480×480 (crisp pixel scaling)
- **Origin**: Top-left; each pixel = `<rect x="i" y="j" width="1" height="1" fill="..."/>`

### Pixel Color Roles

| Code | Role | Default Hex |
|------|------|-------------|
| 0 | Background | `#ffffff` |
| 1 | Body | `#e63946` |
| 2 | Claws / darker red | `#c41e3a` |
| 3 | Eyes | `#000000` |
| 4 | Belly (yellow/orange) | `#e9c46a` |
| 5 | Tail bands (navy) | `#1d3557` |
| 6 | Antennae | `#8b4513` |

**Trait variants**: Swap palette per token (Classic, Blue, Green, Gold, Purple).

### Pixel Map Storage (Solidity)

- Store as `string` of 576 chars (24×24), each char = color index '0'-'6'
- Or pack into bytes (e.g. 4 bits per pixel = 288 bytes)
- Contract loops over grid, emits `<rect>` for each non-background pixel

### Testing & Viewing Art

**Option A: HTML preview (recommended)** — `preview/index.html`

- No build step; open in browser: `file:///path/to/ClawPunks/preview/index.html` or `npx serve preview`
- Color pickers for body, claw, background; preset buttons (Classic, Blue, Green, Gold, Purple)
- Updates instantly as you change values
- Mirrors contract logic; iterate design before Solidity

**Option B: Contract + script**

- Deploy to Sepolia, call `tokenURI(tokenId)`, decode Base64, render in HTML
- Or: Hardhat/Forge script that calls `tokenURI` and writes SVG to file

**Option C: Block explorer**

- After deploy: view NFT on OpenSea testnet or Basescan; they render `tokenURI` image

### SVG Construction (Pixel Grid)

Build Claw SVG from pixel map + palette:

```solidity
// For each (x,y) in 24x24 grid:
//   char c = pixelMap[y*24 + x];
//   if (c != '0') rects += abi.encodePacked('<rect x="', x*10, '" y="', y*10, '" width="10" height="10" fill="', palette[c], '"/>');
string memory svg = string(abi.encodePacked(
  '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="240" viewBox="0 0 240 240">',
  '<rect width="240" height="240" fill="', bgColor, '"/>',
  rects,
  '</svg>'
));
```

---

## Implementation Plan

### 1. Contract: `ClawPunks.sol`

- **Location**: `contracts/ClawPunks.sol`
- **Inherit**: ERC721 (OpenZeppelin) + Ownable
- **Storage**:
  - `mapping(uint256 => PunkData) punkData` — traits per token (body color, claw color, optional accessories)
  - Trait SVG fragments: constants or library for Claw base + variant layers
- **Mint**: `premint(address to, uint256 quantity)` — owner-only, mints to `to` (treasury or owner). Traits assigned per tokenId (deterministic or from seed).
- **Airdrop**: No contract function needed. Owner/server holds preminted tokens; uses standard `transferFrom(owner, agentWallet, tokenId)` or `safeTransferFrom`. Owner must `setApprovalForAll(serverRelayer, true)` if using a relayer.
- **tokenURI**: Build SVG from 24×24 pixel map + color palette, Base64 encode, return data URI (EthereumNorthStar pattern)

### 2. Project Structure

```
ClawPunks/
├── preview/
│   └── index.html             # Art preview — open in browser, no build
├── contracts/
│   ├── ClawPunks.sol          # Main ERC721 + procedural Claw SVG
│   └── ClawPunksTraits.sol    # (Optional) Trait SVG fragments / color palettes
├── deploy/
│   └── deploy_clawpunks.ts    # Deploy to Sepolia / mainnet
├── server/                    # Backend API for airdrop
│   ├── api/
│   │   └── airdrop/           # POST: wallet address -> transfer ClawPunk
│   ├── lib/
│   │   └── clawpunks.ts       # Contract interaction (viem/ethers)
│   └── db/                    # Track claimed wallets, next tokenId to send
├── hardhat.config.ts          # Sepolia + mainnet
├── PLAN.md                    # This file
└── package.json
```

### 3. Supply and Mint Model

- **Supply**: 10,000 (like CryptoPunks)
- **Mint model**: Admin premint + airdrop via backend API

```
Admin -> Contract: premint(batch) - mints to contract/treasury
Agent -> Server: API call with wallet address
Server -> Contract: transferFrom(treasury, agentWallet, tokenId)
Contract -> Agent: ClawPunk NFT transferred
```

- Admin premints all 10,000 (or in batches) to contract owner/treasury address
- Claw agent calls backend API with their wallet address to claim free airdrop
- Server (backend) holds admin key or uses relayer; calls `transferFrom(owner, agentWallet, tokenId)` or `safeTransferFrom` to send ClawPunk to agent
- Backend needs: approved API auth, rate limiting, duplicate-claim prevention (track which tokenIds already airdropped)

### 4. Backend API (airdrop)

- Endpoint: `POST /api/airdrop` with `{ "wallet": "0x..." }`
- Auth: API key or Claw agent auth (to prevent abuse)
- Logic: Assign next available tokenId from preminted pool, call `safeTransferFrom(owner, wallet, tokenId)`, record claim in DB
- Requires: Server wallet with ETH for gas, owner's private key or `approve` + relayer

### 5. Deployment

- **Testnet**: Ethereum Sepolia
- **Production**: Ethereum mainnet
