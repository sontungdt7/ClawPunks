import { streamMentions } from "./twitter.js";
import { streamMoltbookClaims } from "./moltbook.js";
import { config } from "./config.js";

async function main() {
  console.log("ClawPunks Airdrop Bot starting...");

  if (config.moltbook.enabled) {
    await streamMoltbookClaims();
  }

  if (config.twitter.enabled) {
    await streamMentions();
  }

  if (!config.moltbook.enabled && !config.twitter.enabled) {
    console.log("No polling sources enabled. Set MOLTBOOK_POST_ID or TWITTER_POLLING_ENABLED=true");
  }
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
