import { createPublicClient, http, Address, Chain } from "viem";
import * as chains from "viem/chains";
import fs from "fs";
import path from "path";
import assert from "assert";
import { abiUnifiedStore } from "./abis";

// Get all keys from the UnifiedStore contract
const keys = [
  "GiftedAccountGuardian",
  "GiftedAccount",
  "ERC6551Registry",
  "GiftedBox",
  "Vault",
  "GasSponsorBook",
  "NFTVault",
  "GiftedBoxImplementation",
  "GiftedAccountImplementation",
  "TOKEN_USDT",
  "TOKEN_USDC",
  "TOKEN_WBTC",
  "UNISWAP_QUOTER",
  "UNISWAP_ROUTER",
  "TOKEN_WETH",
];

function getChainById(networkId: string): Chain | undefined {
  const chain = Object.values(chains).find((c) => c.id === parseInt(networkId));

  if (!chain) {
    console.error(`Chain not found for network ID ${networkId}`);
    return undefined;
  }

  const chainName = chain.name.toUpperCase().replace(/ /g, "_");
  const envRpcUrl = process.env[`${chainName}_RPC_URL`];
  console.log(
    `Using RPC URL from environment variable ${chainName}_RPC_URL: ${
      envRpcUrl ? envRpcUrl : "not set"
    }`
  )

  if (envRpcUrl) {
    const clonedChain = { ...chain };
    clonedChain.rpcUrls = {
      ...chain.rpcUrls,
      default: { http: [envRpcUrl as any] },
    };
    return clonedChain;
  }

  return chain;
}

async function updateConfig() {
  // Get the deployment environment
  const deployEnv = process.env.DEPLOY_ENV;
  assert(deployEnv, "DEPLOY_ENV is not set");

  // Read the addresses JSON file
  const addressesPath = path.join(
    __dirname,
    "..",
    "config",
    `${deployEnv}_addresses.json`
  );
  const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf-8"));

  // Process all networks concurrently
  await Promise.all(
    Object.entries(addresses).map(async ([networkId, networkData]) => {
      const unifiedStoreAddress = (networkData as { UnifiedStore?: Address })
        .UnifiedStore;

      if (!unifiedStoreAddress) {
        console.error(`UnifiedStore address not found for network ${networkId}`);
        return;
      }

      const chain = getChainById(networkId);
      if (!chain) {
        console.error(`Chain not found for network ID ${networkId}`);
        return;
      }

      // Create a public client
      const publicClient = createPublicClient({
        chain,
        transport: http(),
      });

      try {
        // Fetch addresses for all keys concurrently
        const keyResults = await Promise.all(
          keys.map(async (key) => {
            try {
              const address = await publicClient.readContract({
                address: unifiedStoreAddress,
                abi: abiUnifiedStore,
                functionName: "getAddress",
                args: [key],
              });
              return { key, address };
            } catch (error) {
              console.error(
                `Error fetching address for key ${key} on network ${networkId}:`,
                error
              );
              return null;
            }
          })
        );

        // Update addresses with successful results
        keyResults.forEach((result) => {
          if (result) {
            addresses[networkId][result.key] = result.address;
          }
        });

        console.log(
          `Configuration updated successfully for network ${deployEnv} - ${networkId}`
        );
      } catch (error) {
        console.error(
          `Error updating configuration for network ${deployEnv} - ${networkId}:`,
          error
        );
      }
    })
  );

  // Write the updated configuration back to the file
  fs.writeFileSync(addressesPath, JSON.stringify(addresses, null, 2));
  console.log(`All configurations updated and saved for ${deployEnv}`);
}

updateConfig().catch(console.error);
