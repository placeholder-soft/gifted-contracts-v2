import { spawn } from "node:child_process";
import PQueue from "p-queue";

const colors = {
  base_sepolia: "\x1b[31m", // Red
  sepolia: "\x1b[32m", // Green
  zora_sepolia: "\x1b[33m", // Yellow
  arbitrum_sepolia: "\x1b[34m", // Blue
} as const;

const resetColor = "\x1b[0m";

async function deploy_testnet() {
  const networks = [
    "base_sepolia",
    "sepolia",
    // "zora_sepolia",
    "arbitrum_sepolia",
  ] as const;

  console.log(`Deploying NFTVault to ${networks.join(", ")}...`);
  const queue = new PQueue({ concurrency: 10 });

  for (const network of networks) {
    queue.add(async () => {
      try {
        console.log(
          `${colors[network]}Deploying NFTVault to ${network}...${resetColor}`
        );
        const command = `forge script script/deploy.vault.s.sol --rpc-url ${network} -vvvv --broadcast --verify --slow`;
        // const command = `forge script script/deploy.vault.s.sol --rpc-url ${network} -vvvv`;
        const child = spawn(command, { shell: true });

        let output = "";
        child.stdout.on("data", (data: Buffer) => {
          const message = data.toString().trim();
          console.log(`${colors[network]}[${network}] ${message}${resetColor}`);
          output += message + "\n";
        });

        child.stderr.on("data", (data: Buffer) => {
          console.error(
            `${colors[network]}[${network}] Error: ${data
              .toString()
              .trim()}${resetColor}`
          );
        });

        await new Promise<void>((resolve, reject) => {
          child.on("close", (code: number) => {
            if (code === 0) {
              console.log(
                `${colors[network]}[${network}] Deployment completed successfully${resetColor}`
              );
              resolve();
            } else {
              console.error(
                `${colors[network]}[${network}] Deployment failed with code ${code}${resetColor}`
              );
              reject(new Error(`Deployment failed for ${network}`));
            }
          });
        });
        console.log(
          `${colors[network]}Deployment output for ${network}:${resetColor}`
        );
        console.log(output);
      } catch (error) {
        console.error(
          `${colors[network]}Error deploying NFTVault for ${network}:${resetColor}`
        );
        console.error(error);
      }
    });
  }

  await queue.onIdle();

  console.log("NFTVault deployment completed.");
}

deploy_testnet();
