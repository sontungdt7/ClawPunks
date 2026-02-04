import { streamMentions } from "./twitter.js";

async function main() {
  console.log("ClawPunks Airdrop Bot starting...");
  await streamMentions();
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
