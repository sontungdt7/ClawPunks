import "dotenv/config";

function requireEnv(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env: ${name}`);
  return v;
}

function getEnv(name: string, def: string): string {
  return process.env[name] ?? def;
}

function getEnvInt(name: string, def: number): number {
  const v = process.env[name];
  return v ? parseInt(v, 10) : def;
}

export const config = {
  twitter: {
    enabled: process.env.TWITTER_POLLING_ENABLED === "true",
    apiKey: getEnv("TWITTER_API_KEY", ""),
    apiSecret: getEnv("TWITTER_API_SECRET", ""),
    accessToken: getEnv("TWITTER_ACCESS_TOKEN", ""),
    accessSecret: getEnv("TWITTER_ACCESS_SECRET", ""),
    botHandle: "fomo4claw_bot",
    pollIntervalMs: getEnvInt("POLL_INTERVAL_MS", 900_000),
  },
  moltbook: {
    enabled: true,
    mode: (getEnv("MOLTBOOK_MODE", "posts") as "posts" | "comments") === "comments" ? "comments" : "posts",
    postId: getEnv(
      "MOLTBOOK_POST_ID",
      "460edcbf-39e6-41b9-81f9-67e182dfd911"
    ),
    apiKey: getEnv("MOLTBOOK_API_KEY", ""),
    pollIntervalMs: getEnvInt("MOLTBOOK_POLL_INTERVAL_MS", 60_000), // 1 min default
  },
  ethereum: {
    rpcUrl: getEnv("ETHEREUM_RPC_URL", "https://eth.llamarpc.com"),
    chainId: parseInt(getEnv("CHAIN_ID", "1"), 10),
    airdropWalletKey: requireEnv("AIRDROP_WALLET_PRIVATE_KEY"),
  },
  clawPunks: {
    contract: getEnv(
      "CLAWPUNKS_CONTRACT",
      "0xd99adfa07f97c444dcdddaa70b3c58a9d33124ee"
    ) as `0x${string}`,
  },
  erc8004: {
    registry: getEnv("ERC8004_REGISTRY", "") as `0x${string}`,
    skipCheck: process.env.SKIP_ERC8004_CHECK === "true",
  },
};
