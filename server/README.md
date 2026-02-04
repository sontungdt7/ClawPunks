# ClawPunks Airdrop Server

Twitter bot that listens for mentions of `@fomo4claw_bot` and airdrops ClawPunk NFTs to eligible Agent Wallets.

## Flow

1. User tweets: `@fomo4claw_bot #ClawPunkAirdrop Agent Wallet: 0x....`
2. Server parses the mention, extracts the Agent Wallet address
3. Server checks:
   - Agent Wallet has not claimed before (1 claim per wallet)
   - Agent Wallet is registered with ERC8004 on Ethereum
4. If pass: server transfers 1 ClawPunk NFT from airdrop wallet to Agent Wallet
5. Server replies: `Airdropped ClawPunk #tokenId to "0x...".`

## Setup

### 1. Twitter API

Create a project at [developer.twitter.com](https://developer.twitter.com/) and get:
- API Key, API Secret
- Access Token, Access Secret (with Read + Write permissions)

**Twitter API Free & Basic** tier works: uses search/recent (polling) instead of filtered stream. Filtered stream requires Pro ($5k/mo).

### 2. Ethereum

- **Airdrop wallet**: Holds preminted ClawPunks. Must have ETH for gas.
- **Premint**: Owner must premint tokens to the airdrop wallet first. Tokens are airdropped in order (0, 1, 2, ...).

```bash
# From contracts/
cast send $CLAWPUNKS "premint(address,uint256)" $AIRDROP_WALLET 2000 --private-key $OWNER_KEY
```

### 3. ERC8004 Registry

Agent Wallets must be registered in the ERC8004 Identity Registry on Ethereum. Set `ERC8004_REGISTRY` to the deployed Identity Registry address.

For testnet (Sepolia) where a registry may not exist, set `SKIP_ERC8004_CHECK=true`.

### 4. Config

```bash
cp env.example .env
# Edit .env with your keys
```

### 5. Run

```bash
npm install
npm run build
npm start
```

For development with auto-reload:

```bash
npm run dev
```

## Message Format

```
#ClawPunkAirdrop
Agent Wallet: 0x1234567890abcdef1234567890abcdef12345678
```

The phrase and wallet line can appear in any order; parsing is case-insensitive for the trigger phrase.

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| TWITTER_API_KEY | Yes | Twitter API key |
| TWITTER_API_SECRET | Yes | Twitter API secret |
| TWITTER_ACCESS_TOKEN | Yes | Twitter access token |
| TWITTER_ACCESS_SECRET | Yes | Twitter access secret |
| AIRDROP_WALLET_PRIVATE_KEY | Yes | Private key of wallet holding NFTs |
| ETHEREUM_RPC_URL | No | RPC URL (default: https://eth.llamarpc.com) |
| CLAWPUNKS_CONTRACT | No | ClawPunks NFT contract address |
| ERC8004_REGISTRY | No | ERC8004 Identity Registry address |
| CHAIN_ID | No | 1 = mainnet, 11155111 = Sepolia |
| SKIP_ERC8004_CHECK | No | Set to "true" to skip ERC8004 verification |
