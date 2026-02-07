import { config } from "./config.js";
import { executeAirdrop } from "./airdrop.js";
import {
  isMoltbookCommentProcessed,
  markMoltbookCommentProcessed,
  isMoltbookPostProcessed,
  markMoltbookPostProcessed,
} from "./db.js";

const POST_ID = config.moltbook.postId;
const BASE_URL = "https://www.moltbook.com";

const CLAIM_TRIGGER = "!CLAIM CLAWPUNKS AIRDROP";

/**
 * Parse text for claim format:
 * !CLAIM CLAWPUNKS AIRDROP
 * Agent Wallet: 0x....
 */
function parseClaimText(text: string): `0x${string}` | null {
  const normalized = text.replace(/\s+/g, " ").trim();
  if (!normalized.toUpperCase().includes(CLAIM_TRIGGER.toUpperCase())) {
    return null;
  }
  const match = text.match(/Agent\s*Wallet\s*:?\s*(0x[a-fA-F0-9]{40})/i);
  if (!match) return null;
  return match[1] as `0x${string}`;
}

async function handleMoltbookClaimItem(
  item: { id: string; content: string; author_id?: string },
  type: "comment" | "post"
): Promise<void> {
  const agentWallet = parseClaimText(item.content);
  if (!agentWallet) return;

  console.log(
    `[Claim] Parsed wallet ${agentWallet} from Moltbook ${type} ${item.id}`
  );

  const result = await executeAirdrop(agentWallet, item.id);
  console.log(
    result.ok
      ? `[Airdrop] ClawPunk #${result.tokenId} → ${agentWallet}`
      : `[Airdrop] Failed: ${result.reason}`
  );
}

export async function handleMoltbookComment(comment: {
  id: string;
  content: string;
  author_id?: string;
}): Promise<void> {
  return handleMoltbookClaimItem(comment, "comment");
}

let claimLock: Promise<void> = Promise.resolve();

interface MoltbookComment {
  id: string;
  content: string;
  author_id?: string;
}

/**
 * Fetch comments for a Moltbook post.
 * Tries common API patterns; add MOLTBOOK_API_KEY if auth required.
 */
async function fetchPostComments(): Promise<MoltbookComment[]> {
  const headers: Record<string, string> = {
    Accept: "application/json",
    "User-Agent": "ClawPunks-Airdrop-Bot/1.0",
  };
  if (config.moltbook.apiKey) {
    headers["Authorization"] = `Bearer ${config.moltbook.apiKey}`;
  }

  // Try GET /api/v1/posts/{id}/comments first
  let data: unknown = null;
  const commentsUrl = `${BASE_URL}/api/v1/posts/${POST_ID}/comments`;
  const commentsRes = await fetch(commentsUrl, { headers });

  if (commentsRes.ok) {
    data = await commentsRes.json();
  } else {
    // Fallback: try GET /api/v1/posts/{id} (comments may be nested)
    if (commentsRes.status === 404 || commentsRes.status === 401) {
      const postUrl = `${BASE_URL}/api/v1/posts/${POST_ID}`;
      const postRes = await fetch(postUrl, { headers });
      if (postRes.ok) data = await postRes.json();
    }
    if (!data) {
      if (commentsRes.status === 401 && !config.moltbook.apiKey) {
        console.warn(
          "[Moltbook] 401 - Set MOLTBOOK_API_KEY if comments require auth"
        );
      }
      throw new Error(
        `Moltbook API ${commentsRes.status}: ${commentsRes.statusText}`
      );
    }
  }

  if (!data || typeof data !== "object") return [];

  // Handle various response shapes
  const raw = data as Record<string, unknown>;
  let items: unknown[] = [];
  if (Array.isArray(raw)) items = raw;
  else if (Array.isArray(raw.comments)) items = raw.comments;
  else if (Array.isArray(raw.data)) items = raw.data;
  else if (Array.isArray(raw.items)) items = raw.items;

  const comments: MoltbookComment[] = [];
  for (const item of items) {
    if (!item || typeof item !== "object") continue;
    const o = item as Record<string, unknown>;
    const id = String(o.id ?? o.comment_id ?? o.uuid ?? "");
    const content = String(o.content ?? o.text ?? o.body ?? "");
    if (!id || !content) continue;
    comments.push({
      id,
      content,
      author_id: o.author_id ? String(o.author_id) : undefined,
    });
  }

  // Log comments containing the trigger
  const matching = comments.filter((c) =>
    c.content.toUpperCase().includes(CLAIM_TRIGGER.toUpperCase())
  );
  if (matching.length > 0) {
    console.log(`[Moltbook] Comments containing "${CLAIM_TRIGGER}":`, matching);
  }

  return comments;
}

interface MoltbookPost {
  id: string;
  content: string;
  author_id?: string;
}

/**
 * Fetch posts from Moltbook feed. Paginates through all available posts.
 */
async function fetchAllPosts(): Promise<MoltbookPost[]> {
  const headers: Record<string, string> = {
    Accept: "application/json",
    "User-Agent": "ClawPunks-Airdrop-Bot/1.0",
  };
  if (config.moltbook.apiKey) {
    headers["Authorization"] = `Bearer ${config.moltbook.apiKey}`;
  }

  const posts: MoltbookPost[] = [];
  let offset = 0;
  const limit = 25;
  const maxPages = 10; // safety limit: 250 posts per poll

  for (let page = 0; page < maxPages; page++) {
    const url = `${BASE_URL}/api/v1/posts?limit=${limit}&offset=${offset}&sort=new`;
    const res = await fetch(url, { headers });
    if (!res.ok) {
      throw new Error(`Moltbook API ${res.status}: ${res.statusText}`);
    }

    const data = (await res.json()) as {
      success?: boolean;
      posts?: Array<{
        id?: string;
        content?: string;
        author?: { id?: string };
      }>;
      has_more?: boolean;
      next_offset?: number;
    };

    const items = data.posts ?? [];
    for (const item of items) {
      const id = String(item.id ?? "");
      const content = String(item.content ?? "");
      if (!id || !content) continue;
      posts.push({
        id,
        content,
        author_id: item.author?.id ? String(item.author.id) : undefined,
      });
    }

    if (!data.has_more || items.length === 0) break;
    offset = data.next_offset ?? offset + limit;
  }

  const matching = posts.filter((p) =>
    p.content.toUpperCase().includes(CLAIM_TRIGGER.toUpperCase())
  );
  if (matching.length > 0) {
    console.log(`[Moltbook] Posts containing "${CLAIM_TRIGGER}":`, matching.length);
  }

  return posts;
}

async function pollMoltbookPosts(): Promise<number> {
  try {
    const posts = await fetchAllPosts();
    console.log(`[Moltbook] Fetched ${posts.length} posts (sort=new)`);
    for (const post of posts) {
      if (
        !post.id ||
        !post.content ||
        isMoltbookPostProcessed(post.id)
      )
        continue;

      markMoltbookPostProcessed(post.id);
      claimLock = claimLock.then(() =>
        handleMoltbookClaimItem(
          { id: post.id, content: post.content, author_id: post.author_id },
          "post"
        )
      );
    }
    return config.moltbook.pollIntervalMs;
  } catch (err) {
    console.error("[Moltbook] Poll error:", err);
    return config.moltbook.pollIntervalMs;
  }
}

async function pollMoltbookComments(): Promise<number> {
  try {
    const comments = await fetchPostComments();
    for (const comment of comments) {
      if (
        !comment.id ||
        !comment.content ||
        isMoltbookCommentProcessed(comment.id)
      )
        continue;

      markMoltbookCommentProcessed(comment.id);
      claimLock = claimLock.then(() =>
        handleMoltbookComment({
          id: comment.id,
          content: comment.content,
          author_id: comment.author_id,
        })
      );
    }
    return config.moltbook.pollIntervalMs;
  } catch (err) {
    console.error("[Moltbook] Poll error:", err);
    return config.moltbook.pollIntervalMs;
  }
}

/**
 * Start polling Moltbook for claim triggers.
 * Mode "posts": scans all posts from the feed.
 * Mode "comments": scans comments on a specific post.
 */
export async function streamMoltbookClaims(): Promise<void> {
  const intervalMs = config.moltbook.pollIntervalMs;
  const mode = config.moltbook.mode;
  const pollFn = mode === "comments" ? pollMoltbookComments : pollMoltbookPosts;

  console.log(
    mode === "comments"
      ? `Polling Moltbook post ${POST_ID} comments every ${intervalMs / 1000}s`
      : `Polling Moltbook posts feed every ${intervalMs / 1000}s`
  );

  function scheduleNext(delayMs: number) {
    setTimeout(async () => {
      const nextDelay = await pollFn();
      scheduleNext(nextDelay);
    }, delayMs);
  }

  scheduleNext(0);
}

/** @deprecated Use streamMoltbookClaims */
export const streamMoltbookComments = streamMoltbookClaims;
