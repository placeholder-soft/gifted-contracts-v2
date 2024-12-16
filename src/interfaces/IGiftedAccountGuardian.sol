// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IUnifiedStore.sol";

interface IGiftedAccountGuardian {
  event Upgraded(address indexed implementation);
  event ExecutorUpdated(address executor, bool trusted);

  function isExecutor(address executor) external view returns (bool);

  function setExecutor(address executor, bool trusted) external;

  function getImplementation() external view returns (address);

  function getUnifiedStore() external view returns (IUnifiedStore);
}
