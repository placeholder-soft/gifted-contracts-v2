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
  "sepolia",
  "base_sepolia",
  "arbitrum_sepolia",
//   "zora_sepolia",
  // Add other networks here as needed
] as const;

async function sendFunds() {
  console.log(`Sending funds on ${networks.join(", ")}...`);
  const queue = new PQueue({ concurrency: 10 });

  for (const network of networks) {
    queue.add(async () => {
      const colorIndex = networks.indexOf(network) % colors.length;
      try {
        console.log(
          `${colors[colorIndex]}Sending funds on ${network}...${resetColor}`
        );
        const command = `forge script script/send-funds.testnet.s.sol --rpc-url ${network} -vvvv --broadcast`;
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
                `${colors[colorIndex]}[${network}] Send funds completed successfully${resetColor}`
              );
              resolve();
            } else {
              console.error(
                `${colors[colorIndex]}[${network}] Send funds failed with code ${code}${resetColor}`
              );
              reject(new Error(`Send funds failed for ${network}`));
            }
          });
        });
        console.log(
          `${colors[colorIndex]}Send funds output for ${network}:${resetColor}`
        );
        console.log(output);
      } catch (error) {
        console.error(
          `${colors[colorIndex]}Error sending funds for ${network}:${resetColor}`
        );
        console.error(error);
      }
    });
  }

  await queue.onIdle();

  console.log("Send funds operation completed.");
}

sendFunds();
