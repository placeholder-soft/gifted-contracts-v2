import { createPublicClient, createWalletClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { sepolia } from "viem/chains";

// Contract addresses (Sepolia)
const SWAP_ROUTER = "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E";
const USDC = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238";
const WETH9 = "0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14";
const POOL_FEE = 100; // 0.01%

// ABI for the swap router (only the functions we need)
const SWAP_ROUTER_ABI = [
  {
    inputs: [
      {
        components: [
          { name: "tokenIn", type: "address" },
          { name: "tokenOut", type: "address" },
          { name: "fee", type: "uint24" },
          { name: "recipient", type: "address" },
          { name: "amountIn", type: "uint256" },
          { name: "amountOutMinimum", type: "uint256" },
          { name: "sqrtPriceLimitX96", type: "uint160" },
        ],
        name: "params",
        type: "tuple",
      },
    ],
    name: "exactInputSingle",
    outputs: [{ name: "amountOut", type: "uint256" }],
    stateMutability: "payable",
    type: "function",
  },
];

async function main() {
  // Create Viem clients
  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(),
  });

  if (!process.env.PRIVATE_KEY) {
    throw new Error("PRIVATE_KEY environment variable is required");
  }

  const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);
  const walletClient = createWalletClient({
    account,
    chain: sepolia,
    transport: http(),
  });

  // Amount of USDC to swap (with 6 decimals)
  const amountIn = 1000000n; // 1 USDC

  // Prepare swap parameters
  const params = {
    tokenIn: USDC,
    tokenOut: WETH9,
    fee: POOL_FEE,
    recipient: account.address,
    // deadline: BigInt(Math.floor(Date.now() / 1000) + 10000), // 10000 seconds from now
    amountIn,
    amountOutMinimum: 0n, // In production, use an oracle for slippage protection
    sqrtPriceLimitX96: 0n,
  };

  try {
    // // First, approve USDC spending
    // console.log("Approving USDC...");
    // const { request: approvalRequest } = await publicClient.simulateContract({
    //   address: USDC,
    //   abi: [
    //     {
    //       inputs: [
    //         { name: "spender", type: "address" },
    //         { name: "amount", type: "uint256" },
    //       ],
    //       name: "approve",
    //       outputs: [{ name: "", type: "bool" }],
    //       stateMutability: "nonpayable",
    //       type: "function",
    //     },
    //   ],
    //   functionName: "approve",
    //   args: [SWAP_ROUTER, amountIn],
    //   account,
    // });

    // const approvalHash = await walletClient.writeContract(approvalRequest);
    // console.log("Approval transaction hash:", approvalHash);

    // // Wait for approval to be mined
    // await publicClient.waitForTransactionReceipt({ hash: approvalHash });

    // Execute the swap
    console.log("Executing swap...");
    // const { request } = await publicClient.simulateContract({
    //   address: SWAP_ROUTER,
    //   abi: SWAP_ROUTER_ABI,
    //   functionName: "exactInputSingle",
    //   args: [params],
    //   account,
    // });

    const hash = await walletClient.writeContract({
      address: SWAP_ROUTER,
      abi: SWAP_ROUTER_ABI,
      functionName: "exactInputSingle",
      args: [params],
      account,
      gas: 1000000n
    });
    console.log("Swap transaction hash:", hash);

    // Wait for the swap transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log("Swap completed!");
    console.log(`Swapped ${amountIn} USDC for ETH`);
  } catch (error) {
    console.error("Error executing swap:", error);
  }
}

main().catch(console.error);
