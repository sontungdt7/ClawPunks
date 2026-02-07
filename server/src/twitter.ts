import { TwitterApi } from "twitter-api-v2";
import { config } from "./config.js";
import { executeAirdrop } from "./airdrop.js";
import { isTweetProcessed, markTweetProcessed } from "./db.js";

const BOT_HANDLE = config.twitter.botHandle;

// OAuth 1.0a User Context - lazy init when Twitter is actually used
let userClient: TwitterApi | null = null;
function getTwitterClient(): TwitterApi {
  if (!userClient) {
    if (!config.twitter.apiKey || !config.twitter.apiSecret) {
      throw new Error("Twitter API credentials required when TWITTER_POLLING_ENABLED=true");
    }
    userClient = new TwitterApi({
  appKey: config.twitter.apiKey,
  appSecret: config.twitter.apiSecret,
    accessToken: config.twitter.accessToken,
    accessSecret: config.twitter.accessSecret,
  });
  }
  return userClient;
}

/**
 * Parse mention text for claim format:
 * !Claim ClawPunk Airdrop
 * Agent Wallet: 0x....
 */
function parseClaimMention(text: string): `0x${string}` | null {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (!normalized.toLowerCase().includes("#clawpunkairdrop")) {
    return null;
  }
  const match = text.match(/Agent\s*Wallet\s*:?\s*(0x[a-fA-F0-9]{40})/i);
  if (!match) return null;
  return match[1] as `0x${string}`;
}

export async function handleMention(tweet: {
  id: string;
  text: string;
  author_id?: string;
}): Promise<void> {
  const agentWallet = parseClaimMention(tweet.text);
  if (!agentWallet) return;

  console.log(`[Claim] Parsed wallet ${agentWallet} from tweet ${tweet.id}`);

  const result = await executeAirdrop(agentWallet, tweet.id);

  const replyText = result.ok
    ? `Airdropped ClawPunk #${result.tokenId} to "${agentWallet}".`
    : `Airdrop failed: ${result.reason}.`;

  try {
    await getTwitterClient().readWrite.v2.reply(replyText, tweet.id);
    console.log(`[Reply] ${replyText}`);
  } catch (err) {
    console.error("Failed to reply:", err);
  }
}

// Process one claim at a time to avoid race conditions
let claimLock: Promise<void> = Promise.resolve();

/**
 * Poll for mentions using search/recent (works on Free & Basic tier).
 * Free tier: 1 request per 15 min. Basic: 450/15min.
 */
async function pollMentions(): Promise<number> {
  try {
    const paginator = await getTwitterClient().readWrite.v2.search(`@${BOT_HANDLE}`, {
      "tweet.fields": ["author_id", "created_at"],
      expansions: ["author_id"],
      max_results: 100,
    });

    const tweets = paginator.tweets ?? [];
    for (const tweet of tweets) {
      if (!tweet.id || !tweet.text || isTweetProcessed(tweet.id)) continue;

      markTweetProcessed(tweet.id);
      claimLock = claimLock.then(() =>
        handleMention({
          id: tweet.id,
          text: tweet.text,
          author_id: tweet.author_id,
        })
      );
    }
    return config.twitter.pollIntervalMs;
  } catch (err: unknown) {
    const e = err as { code?: number; rateLimit?: { reset?: number } };
    if (e?.code === 429 && e?.rateLimit?.reset) {
      const waitSec = Math.max(60, e.rateLimit.reset - Math.floor(Date.now() / 1000));
      console.log(`Rate limited (429). Waiting ${waitSec}s until reset...`);
      return waitSec * 1000;
    }
    console.error("Poll error:", err);
    return config.twitter.pollIntervalMs;
  }
}

/**
 * Start polling for mentions. Works with Free & Basic API tier.
 * Free tier: 1 search/15min → use POLL_INTERVAL_MS=900000 (default).
 */
export async function streamMentions(): Promise<void> {
  const intervalMs = config.twitter.pollIntervalMs;
  console.log(
    `Polling for @${BOT_HANDLE} mentions every ${intervalMs / 1000}s (Free: 1 req/15min)`
  );

  function scheduleNext(delayMs: number) {
    setTimeout(async () => {
      const nextDelay = await pollMentions();
      scheduleNext(nextDelay);
    }, delayMs);
  }

  scheduleNext(0);
}
