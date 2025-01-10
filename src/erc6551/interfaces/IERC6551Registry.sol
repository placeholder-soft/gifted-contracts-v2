// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IERC6551Registry {
  event AccountCreated(
    address account,
    bytes32 bytecodeHash,
    bytes32 salt
  );

  error AccountCreationFailed();

  error InitializationFailed();

  function createAccount(
    bytes32 bytecodeHash,
    uint256 salt,
    bytes calldata initData
  ) external returns (address);

  function account(
    bytes32 bytecodeHash,
    uint256 salt,
    bytes calldata initData
  ) external view returns (address);
}
