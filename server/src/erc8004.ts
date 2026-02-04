import { createPublicClient, http, type Address } from "viem";
import { mainnet, sepolia } from "viem/chains";
import { config } from "./config.js";

const ERC721_BALANCE_OF_ABI = [
  {
    inputs: [{ name: "owner", type: "address" }],
    name: "balanceOf",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
] as const;

const chain = config.ethereum.chainId === 1 ? mainnet : sepolia;
const client = createPublicClient({
  chain,
  transport: http(config.ethereum.rpcUrl),
});

/**
 * Check if an address is registered in the ERC8004 Identity Registry on Ethereum.
 * ERC8004 Identity Registry is ERC721; each agent = 1 token. Owner of token = registered agent.
 * balanceOf(addr) > 0 means the address owns at least one agent token = registered.
 */
export async function isRegisteredWithERC8004(
  address: Address
): Promise<boolean> {
  if (config.erc8004.skipCheck || !config.erc8004.registry) {
    return true;
  }
  try {
    const balance = await client.readContract({
      address: config.erc8004.registry,
      abi: ERC721_BALANCE_OF_ABI,
      functionName: "balanceOf",
      args: [address],
    });
    return balance > 0n;
  } catch (err) {
    console.error("ERC8004 check failed:", err);
    return false;
  }
}
