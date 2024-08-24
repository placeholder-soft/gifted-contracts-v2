import { spawn } from "node:child_process";
import PQueue from "p-queue";

const colors = [
  "\x1b[32m", // Green
  "\x1b[33m", // Yellow
  "\x1b[34m", // Blue
  "\x1b[35m", // Magenta
  "\x1b[36m", // Cyan
  "\x1b[90m", // Bright Black (Gray)
  "\x1b[92m", // Bright Green
  "\x1b[94m", // Bright Blue
];

const resetColor = "\x1b[0m";

const networks = [
//   "base_sepolia",
//   "sepolia",
//   "arbitrum_sepolia",
  // "zora_sepolia",
  "base"
] as const;

async function deploy() {
  console.log(`Deploying NFTVault to ${networks.join(", ")}...`);
  const queue = new PQueue({ concurrency: 10 });

  for (const network of networks) {
    queue.add(async () => {
      try {
        const colorIndex = networks.indexOf(network) % colors.length;
        console.log(
          `${colors[colorIndex]}Deploying NFTVault to ${network}...${resetColor}`
        );
        const command = `forge script script/deploy.vault.s.sol --rpc-url ${network} -vvvv --broadcast --verify --slow`;
        // const command = `forge script script/deploy.vault.s.sol --rpc-url ${network} -vvvv`;
        const child = spawn(command, { shell: true });

        let output = "";
        child.stdout.on("data", (data: Buffer) => {
          const message = data.toString().trim();
          console.log(
            `${colors[colorIndex]}[${network}] ${message}${resetColor}`
          );
          output += message + "\n";
        });

        child.stderr.on("data", (data: Buffer) => {
          console.error(
            `${colors[colorIndex]}[${network}] Error: ${data
              .toString()
              .trim()}${resetColor}`
          );
        });

        await new Promise<void>((resolve, reject) => {
          child.on("close", (code: number) => {
            if (code === 0) {
              console.log(
                `${colors[colorIndex]}[${network}] Deployment completed successfully${resetColor}`
              );
              resolve();
            } else {
              console.error(
                `${colors[colorIndex]}[${network}] Deployment failed with code ${code}${resetColor}`
              );
              reject(new Error(`Deployment failed for ${network}`));
            }
          });
        });
        console.log(
          `${colors[colorIndex]}Deployment output for ${network}:${resetColor}`
        );
        console.log(output);
      } catch (error) {
        console.error(
          `${colors[colorIndex]}Error deploying NFTVault for ${network}:${resetColor}`
        );
        console.error(error);
      }
    });
  }

  await queue.onIdle();

  console.log("NFTVault deployment completed.");
}

deploy();
