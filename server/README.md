# ClawPunks Airdrop Server

Polls [Moltbook](https://www.moltbook.com) for claim requests and airdrops ClawPunk NFTs to eligible Agent Wallets. By default scans all posts; can also scan comments on a specific post. Twitter polling is disabled by default.

## Flow

1. User posts (or comments) on Moltbook with: `!CLAIM CLAWPUNKS AIRDROP` and `Agent Wallet: 0x....`
2. Server parses the comment, extracts the Agent Wallet address
3. Server checks:
   - Agent Wallet has not claimed before (1 claim per wallet)
   - Agent Wallet is registered with ERC8004 on Ethereum
4. If pass: server transfers 1 ClawPunk NFT from airdrop wallet to Agent Wallet
5. Logs result (no reply on Moltbook; Twitter replies if enabled)

## Setup

### 1. Moltbook (default)

**Mode `posts` (default):** Scans all posts from the Moltbook feed for the claim trigger. No API key needed.

**Mode `comments`:** Scans comments on a specific post. Set `MOLTBOOK_POST_ID` and optionally `MOLTBOOK_API_KEY` if the comments endpoint requires auth (apply at [moltbook.com/developers](https://www.moltbook.com/developers)).

### 2. Twitter (optional, disabled by default)

Set `TWITTER_POLLING_ENABLED=true` to also poll Twitter mentions. Create a project at [developer.twitter.com](https://developer.twitter.com/) and get API keys.

### 3. Ethereum

- **Airdrop wallet**: Holds preminted ClawPunks. Must have ETH for gas.
- **Premint**: Owner must premint tokens to the airdrop wallet first. Tokens are airdropped in order (0, 1, 2, ...).

```bash
# From contracts/
cast send $CLAWPUNKS "premint(address,uint256)" $AIRDROP_WALLET 2000 --private-key $OWNER_KEY
```

### 4. ERC8004 Registry

Agent Wallets must be registered in the ERC8004 Identity Registry on Ethereum. Set `ERC8004_REGISTRY` to the deployed Identity Registry address.

For testnet (Sepolia) where a registry may not exist, set `SKIP_ERC8004_CHECK=true`.

### 5. Config

```bash
cp env.example .env
# Edit .env with your keys
```

### 6. Run

```bash
npm install
npm run build
npm start
```

For development with auto-reload:

```bash
npm run dev
```

## Message Format (Moltbook)

```
!CLAIM CLAWPUNKS AIRDROP
Agent Wallet: 0x1234567890abcdef1234567890abcdef12345678
```

The phrase and wallet line can appear in any order; parsing is case-insensitive for the trigger phrase.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| MOLTBOOK_MODE | No | `posts` (default) or `comments` |
| MOLTBOOK_POST_ID | No | Moltbook post UUID when mode=comments |
| MOLTBOOK_API_KEY | No | Moltbook API key if comments endpoint requires auth |
| MOLTBOOK_POLL_INTERVAL_MS | No | Poll interval in ms (default: 60000) |
| TWITTER_POLLING_ENABLED | No | Set "true" to enable Twitter polling |
| TWITTER_API_KEY | If Twitter | Twitter API key |
| TWITTER_API_SECRET | If Twitter | Twitter API secret |
| TWITTER_ACCESS_TOKEN | If Twitter | Twitter access token |
| TWITTER_ACCESS_SECRET | If Twitter | Twitter access secret |
| AIRDROP_WALLET_PRIVATE_KEY | Yes | Private key of wallet holding NFTs |
| ETHEREUM_RPC_URL | No | RPC URL (default: https://eth.llamarpc.com) |
| CLAWPUNKS_CONTRACT | No | ClawPunks NFT contract address |
| ERC8004_REGISTRY | No | ERC8004 Identity Registry address |
| CHAIN_ID | No | 1 = mainnet, 11155111 = Sepolia |
| SKIP_ERC8004_CHECK | No | Set to "true" to skip ERC8004 verification |
