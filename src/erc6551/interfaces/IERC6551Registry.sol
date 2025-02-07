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
    address implementation,
    bytes32 bytecodeHash,
    bytes32 salt,
    bytes calldata initData
  ) external returns (address);

  function account(
    bytes32 salt
  ) external view returns (address);
}
