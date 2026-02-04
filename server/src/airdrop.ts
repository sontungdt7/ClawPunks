import {
  createWalletClient,
  createPublicClient,
  http,
  parseAbi,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { mainnet, sepolia } from "viem/chains";
import { config } from "./config.js";
import { hasClaimed, recordClaim, getNextTokenId } from "./db.js";
import { isRegisteredWithERC8004 } from "./erc8004.js";

const CLAWPUNKS_ABI = parseAbi([
  "function safeTransferFrom(address from, address to, uint256 tokenId)",
  "function balanceOf(address owner) view returns (uint256)",
  "function tokenOfOwnerByIndex(address owner, uint256 index) view returns (uint256)",
]);

const account = privateKeyToAccount(
  config.ethereum.airdropWalletKey as `0x${string}`
);

const chain = config.ethereum.chainId === 1 ? mainnet : sepolia;

const publicClient = createPublicClient({
  chain,
  transport: http(config.ethereum.rpcUrl),
});

const walletClient = createWalletClient({
  account,
  chain,
  transport: http(config.ethereum.rpcUrl),
});

export type AirdropResult =
  | { ok: true; tokenId: number }
  | { ok: false; reason: string };

/**
 * Execute airdrop: verify eligibility, transfer NFT, record claim.
 */
export async function executeAirdrop(
  agentWallet: `0x${string}`,
  tweetId: string
): Promise<AirdropResult> {
  const wallet = agentWallet.toLowerCase();

  if (hasClaimed(wallet)) {
    return { ok: false, reason: "Wallet has already claimed" };
  }

  const registered = await isRegisteredWithERC8004(agentWallet);
  if (!registered) {
    return {
      ok: false,
      reason: "Agent Wallet must be registered with ERC8004 on Ethereum",
    };
  }

  // Get next token to send - we use sequential IDs from our pool
  const tokenId = getNextTokenId();
  if (tokenId >= 10000) {
    return { ok: false, reason: "Airdrop supply exhausted" };
  }

  // Check airdrop wallet has this token
  const balance = await publicClient.readContract({
    address: config.clawPunks.contract,
    abi: CLAWPUNKS_ABI,
    functionName: "balanceOf",
    args: [account.address],
  });
  if (balance === 0n) {
    return {
      ok: false,
      reason: "Airdrop wallet has no NFTs - please premint first",
    };
  }

  // We need to pick a tokenId we actually own. If using sequential, we must premint
  // a contiguous range. For simplicity we use tokenOfOwnerByIndex to get first available.
  // But ERC721 doesn't have tokenOfOwnerByIndex by default - that's ERC721Enumerable.
  // ClawPunks is plain ERC721. So we need to either:
  // 1. Add Enumerable to contract, or
  // 2. Track which tokenIds we've airdropped and pick from balance.
  // For now we'll assume we premint 0..N and airdrop in order. So tokenId 0, 1, 2...
  // getNextTokenId() returns the next to use. We must ensure we've preminted that far.
  // The owner should premint batches to the airdrop wallet. tokenId 0, 1, 2... get sent.

  try {
    const hash = await walletClient!.writeContract({
      address: config.clawPunks.contract,
      abi: CLAWPUNKS_ABI,
      functionName: "safeTransferFrom",
      args: [account.address, agentWallet, BigInt(tokenId)],
    });

    await publicClient.waitForTransactionReceipt({ hash });
    recordClaim(wallet, tokenId, tweetId);
    return { ok: true, tokenId };
  } catch (err) {
    console.error("Airdrop tx failed:", err);
    return {
      ok: false,
      reason: err instanceof Error ? err.message : "Transaction failed",
    };
  }
}
