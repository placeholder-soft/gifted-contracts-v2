// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

interface IQuoter {
  /// @notice Returns the amount out received for a given exact input swap without executing the swap
  /// @param tokenIn The token being swapped in
  /// @param tokenOut The token being swapped out
  /// @param fee The fee tier of the pool, used to determine the correct pool contract
  /// @param amountIn The amount of token in
  /// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
  /// @return amountOut The amount of token received upon executing the swap
  function quoteExactInputSingle(
    address tokenIn,
    address tokenOut,
    uint24 fee,
    uint256 amountIn,
    uint160 sqrtPriceLimitX96
  ) external view returns (uint256 amountOut);
}
