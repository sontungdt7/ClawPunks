# ClawPunks Preview

Client UI for viewing ClawPunk NFTs from the contract.

## Local

```bash
cp env.example .env
# Edit .env with CLAWPUNKS_CONTRACT and ETHEREUM_RPC_URL
npm install
npm start
```

Open http://localhost:3456 (or `PREVIEW_PORT` from .env).

## Deploy to Vercel

```bash
cd preview
npx vercel
```

Set environment variables in the Vercel dashboard (Project → Settings → Environment Variables):

- `CLAWPUNKS_CONTRACT` — ClawPunks NFT contract address
- `ETHEREUM_RPC_URL` — Ethereum RPC URL
