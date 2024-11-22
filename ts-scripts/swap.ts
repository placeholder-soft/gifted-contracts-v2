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

// ABI for WETH9 (only the functions we need)
const WETH_ABI = [
  {
    inputs: [
      { name: "wad", type: "uint256" },
    ],
    name: "withdraw",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    name: "allowance",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "account", type: "address" }],
    name: "balanceOf",
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  }
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
  const amountIn = BigInt(10000e6);

  // Prepare swap parameters
  const params = {
    tokenIn: USDC,
    tokenOut: WETH9,
    fee: POOL_FEE,
    recipient: account.address,
    amountIn,
    amountOutMinimum: 0n, // In production, use an oracle for slippage protection
    sqrtPriceLimitX96: 0n,
  };

  try {
    // First, check current allowance
    console.log("Checking USDC allowance...");
    console.log(`Owner address: ${account.address}`);
    console.log(`Spender address (SwapRouter): ${SWAP_ROUTER}`);
    const currentAllowance = await publicClient.readContract({
      address: USDC,
      abi: [
        {
          inputs: [
            { name: "owner", type: "address" },
            { name: "spender", type: "address" },
          ],
          name: "allowance",
          outputs: [{ name: "", type: "uint256" }],
          stateMutability: "view",
          type: "function",
        },
      ],
      functionName: "allowance",
      args: [account.address, SWAP_ROUTER],
    });

    console.log(`Current allowance: ${currentAllowance} USDC wei`);
    console.log(`Required amount: ${amountIn} USDC wei`);

    // Only approve if current allowance is less than required amount
    if (currentAllowance < amountIn) {
      console.log("\nCurrent allowance is insufficient. Initiating approval...");
      console.log("Approving USDC...");
      const { request: approvalRequest } = await publicClient.simulateContract({
        address: USDC,
        abi: [
          {
            inputs: [
              { name: "spender", type: "address" },
              { name: "amount", type: "uint256" },
            ],
            name: "approve",
            outputs: [{ name: "", type: "bool" }],
            stateMutability: "nonpayable",
            type: "function",
          },
        ],
        functionName: "approve",
        args: [SWAP_ROUTER, 10000000000000000000000000000000n],
        account,
      });

      const approvalHash = await walletClient.writeContract(approvalRequest);
      console.log("Approval transaction hash:", approvalHash);

      // Wait for approval to be mined
      await publicClient.waitForTransactionReceipt({ hash: approvalHash });
    }

    // Execute the swap
    console.log("Executing swap...");
    const { request } = await publicClient.simulateContract({
      address: SWAP_ROUTER,
      abi: SWAP_ROUTER_ABI,
      functionName: "exactInputSingle",
      args: [params],
      account,
    });

    const hash = await walletClient.writeContract(request);
    console.log("Swap transaction hash:", hash);

    // Wait for the swap transaction to be mined
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log("Swap completed!");
    console.log(`Swapped ${amountIn} USDC for WETH`);

    // Query WETH balance before unwrapping
    console.log("Checking WETH balance...");
    const wethBalance = (await publicClient.readContract({
      address: WETH9,
      abi: WETH_ABI,
      functionName: "balanceOf",
      args: [account.address],
    })) as bigint;

    console.log(`Current WETH balance: ${wethBalance} wei`);

    if (wethBalance > 0n) {
      // Unwrap WETH to ETH
      console.log("Unwrapping WETH to ETH...");
      const { request: unwrapRequest } = await publicClient.simulateContract({
        address: WETH9,
        abi: WETH_ABI,
        functionName: "withdraw",
        args: [wethBalance],
        account,
      });

      const unwrapHash = await walletClient.writeContract(unwrapRequest);
      console.log("Unwrap transaction hash:", unwrapHash);

      // Wait for the unwrap transaction to be mined
      const unwrapReceipt = await publicClient.waitForTransactionReceipt({ hash: unwrapHash });
      console.log("Successfully unwrapped WETH to ETH!");
      console.log(`Unwrapped amount: ${wethBalance} wei`);
    } else {
      console.log("No WETH balance to unwrap");
    }
  } catch (error) {
    console.error("Error executing swap:", error);
  }
}

main().catch(console.error);
