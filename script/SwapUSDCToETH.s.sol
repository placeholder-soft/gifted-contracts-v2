// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";
import "@uniswap/swap-router/interfaces/IV3SwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapUSDCToETHScript is Script {
    // Sepolia addresses
    address constant SWAP_ROUTER = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant WETH9 = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    // fee: 0.01%
    uint24 constant POOL_FEE = 100; 
    address public deployer;

    function run() external {
        deployer = getAddressFromConfig("deployer");
        vm.startBroadcast(deployer);

        // Get the SwapRouter contract
        IV3SwapRouter router = IV3SwapRouter(SWAP_ROUTER);
        
        // Amount of USDC to swap (with 6 decimals)
        uint256 amountIn = 1 * 1e6; // 1 USDC - starting with a smaller amount

        // Check USDC balance
        uint256 balance = IERC20(USDC).balanceOf(deployer);
        require(balance >= amountIn, "Insufficient USDC balance");
        console.log("USDC Balance: %s", balance);

        // Approve the router to spend USDC
        IERC20(USDC).approve(SWAP_ROUTER, amountIn);

        // Prepare the parameters for the swap
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: USDC,
                tokenOut: WETH9,
                fee: POOL_FEE,
                recipient: deployer, // Send WETH to this contract first
                // deadline: block.timestamp + 10000,
                amountIn: amountIn,
                amountOutMinimum: 0, // Note: In production, use an oracle to set a reasonable slippage limit
                sqrtPriceLimitX96: 0
            });

        console.log("Attempting to swap %s USDC for ETH", amountIn);

        // Execute the swap and unwrap WETH to ETH
        uint256 amountOut = router.exactInputSingle(params);
        // router.unwrapWETH9(amountOut, deployer); // Unwrap all WETH to ETH and send to deployer
        
        console.log("Swapped %s USDC for %s ETH", amountIn, amountOut);

        vm.stopBroadcast();
    }

    function getAddressFromConfig(string memory key) internal view returns (address) {
        string memory env = vm.envString("DEPLOY_ENV");
        require(bytes(env).length > 0, "DEPLOY_ENV must be set");
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/config/", env, "_addresses.json");
        string memory json = vm.readFile(path);
        bytes memory addressBytes = vm.parseJson(json, string.concat(".", vm.toString(block.chainid), ".", key));
        return abi.decode(addressBytes, (address));
    }
}
