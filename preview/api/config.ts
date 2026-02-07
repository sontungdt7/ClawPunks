export function GET() {
  return Response.json(
    {
      contractAddress:
        process.env.CLAWPUNKS_CONTRACT ||
        "0x47354b283bC2310402974e570703104cE19D4596",
      rpcUrl: process.env.ETHEREUM_RPC_URL || process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
    },
    {
      headers: {
        "Cache-Control": "s-maxage=60, stale-while-revalidate",
      },
    }
  );
}
