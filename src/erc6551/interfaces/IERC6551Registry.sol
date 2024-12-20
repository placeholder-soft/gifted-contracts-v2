// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IERC6551Registry {
  event AccountCreated(
    address account, address implementation, uint256 salt, uint256 chainId, address indexed tokenContract, uint256 indexed tokenId
  );

  error AccountComputeFailed();

  error AccountCreationFailed();

  error InitializationFailed();

  function createAccount(
    address implementation,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId,
    uint256 salt,
    bytes calldata initData
  ) external returns (address);


  function account(address implementation, uint256 chainId, address tokenContract, uint256 tokenId, uint256 salt)
    external
    returns (address);
}
