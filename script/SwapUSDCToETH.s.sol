// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwapUSDCToETHScript is Script {
    // Sepolia addresses
    address constant SWAP_ROUTER = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    uint24 constant POOL_FEE = 500; // 0.05%

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get the SwapRouter contract
        ISwapRouter router = ISwapRouter(SWAP_ROUTER);
        
        // Amount of USDC to swap (with 6 decimals)
        uint256 amountIn = 10 * 1e6; // 10 USDC

        // Approve the router to spend USDC
        IERC20(USDC).approve(SWAP_ROUTER, amountIn);

        // Prepare the parameters for the swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: USDC,
                tokenOut: router.WETH9(),
                fee: POOL_FEE,
                recipient: msg.sender,
                deadline: block.timestamp + 15 minutes,
                amountIn: amountIn,
                amountOutMinimum: 0, // Note: In production, use price oracle to set minimum amount
                sqrtPriceLimitX96: 0
            });

        // Execute the swap
        uint256 amountOut = router.exactInputSingle(params);
        
        console.log("Swapped %s USDC for %s ETH", amountIn, amountOut);

        vm.stopBroadcast();
    }
}
