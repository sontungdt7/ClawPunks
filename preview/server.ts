import "dotenv/config";
import { createServer } from "http";
import { readFileSync, existsSync } from "fs";
import { join, extname } from "path";
import { fileURLToPath } from "url";

const __dirname = fileURLToPath(new URL(".", import.meta.url));

const MIME: Record<string, string> = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css",
  ".svg": "image/svg+xml",
  ".json": "application/json",
  ".ico": "image/x-icon",
};

const server = createServer((req, res) => {
  const url = new URL(req.url || "/", `http://${req.headers.host}`);
  const pathname = url.pathname;

  if (pathname === "/api/config") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        contractAddress:
          process.env.CLAWPUNKS_CONTRACT ||
          "0x47354b283bC2310402974e570703104cE19D4596",
        rpcUrl: process.env.ETHEREUM_RPC_URL || process.env.SEPOLIA_RPC_URL || "https://rpc.sepolia.org",
      })
    );
    return;
  }

  const filePath = join(
    __dirname,
    pathname === "/" ? "index.html" : pathname.replace(/^\//, "")
  );
  if (!existsSync(filePath) || !filePath.startsWith(__dirname)) {
    res.writeHead(404);
    res.end("Not found");
    return;
  }

  try {
    const content = readFileSync(filePath);
    const ext = extname(filePath);
    const mime = MIME[ext] || "application/octet-stream";
    res.writeHead(200, { "Content-Type": mime });
    res.end(content);
  } catch {
    res.writeHead(500);
    res.end("Internal error");
  }
});

const PORT = parseInt(process.env.PREVIEW_PORT || "3456", 10);
server.listen(PORT, () => {
  console.log(`Preview: http://localhost:${PORT}`);
});
