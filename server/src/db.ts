import Database from "better-sqlite3";
import { join } from "path";

const dbPath = join(process.cwd(), "claims.db");
export const db = new Database(dbPath);

db.exec(`
  CREATE TABLE IF NOT EXISTS claims (
    wallet TEXT PRIMARY KEY,
    token_id INTEGER NOT NULL,
    tweet_id TEXT NOT NULL,
    claimed_at INTEGER NOT NULL
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS processed_tweets (
    tweet_id TEXT PRIMARY KEY
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS processed_moltbook_comments (
    comment_id TEXT PRIMARY KEY
  )
`);

db.exec(`
  CREATE TABLE IF NOT EXISTS processed_moltbook_posts (
    post_id TEXT PRIMARY KEY
  )
`);

export function hasClaimed(wallet: string): boolean {
  const row = db.prepare("SELECT 1 FROM claims WHERE wallet = ?").get(wallet);
  return !!row;
}

export function recordClaim(
  wallet: string,
  tokenId: number,
  tweetId: string
): void {
  db.prepare(
    "INSERT INTO claims (wallet, token_id, tweet_id, claimed_at) VALUES (?, ?, ?, ?)"
  ).run(wallet.toLowerCase(), tokenId, tweetId, Date.now());
}

export function getNextTokenId(): number {
  const row = db
    .prepare("SELECT COALESCE(MAX(token_id), -1) + 1 as next FROM claims")
    .get() as { next: number };
  return row.next;
}

export function isTweetProcessed(tweetId: string): boolean {
  const row = db
    .prepare("SELECT 1 FROM processed_tweets WHERE tweet_id = ?")
    .get(tweetId);
  return !!row;
}

export function markTweetProcessed(tweetId: string): void {
  db.prepare(
    "INSERT OR IGNORE INTO processed_tweets (tweet_id) VALUES (?)"
  ).run(tweetId);
}

export function isMoltbookCommentProcessed(commentId: string): boolean {
  const row = db
    .prepare("SELECT 1 FROM processed_moltbook_comments WHERE comment_id = ?")
    .get(commentId);
  return !!row;
}

export function markMoltbookCommentProcessed(commentId: string): void {
  db.prepare(
    "INSERT OR IGNORE INTO processed_moltbook_comments (comment_id) VALUES (?)"
  ).run(commentId);
}

export function isMoltbookPostProcessed(postId: string): boolean {
  const row = db
    .prepare("SELECT 1 FROM processed_moltbook_posts WHERE post_id = ?")
    .get(postId);
  return !!row;
}

export function markMoltbookPostProcessed(postId: string): void {
  db.prepare(
    "INSERT OR IGNORE INTO processed_moltbook_posts (post_id) VALUES (?)"
  ).run(postId);
}
