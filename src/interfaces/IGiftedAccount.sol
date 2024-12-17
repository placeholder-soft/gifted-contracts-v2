// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IGiftedAccountGuardian.sol";

interface IGiftedAccount {
  function isOwner(address caller) external view returns (bool);

  function getGuardian() external view returns (IGiftedAccountGuardian);

  function getTransferERC721PermitMessage(address tokenContract, uint256 tokenId, address to, uint256 deadline)
    external
    view
    returns (string memory);

  function transferERC721(
    address tokenContract,
    uint256 tokenId,
    address to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function getTransferERC1155PermitMessage(
    address tokenContract,
    uint256 tokenId,
    uint256 amount,
    address to,
    uint256 deadline
  ) external view returns (string memory);

  function transferERC1155(
    address tokenContract,
    uint256 tokenId,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function getTransferERC20PermitMessage(address tokenContract, uint256 amount, address to, uint256 deadline)
    external
    view
    returns (string memory);

  function transferERC20(
    address tokenContract,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function getTransferEtherPermitMessage(uint256 amount, address to, uint256 deadline)
    external
    view
    returns (string memory);

  function transferEther(address payable to, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

  function getBatchTransferPermitMessage(bytes[] calldata data, uint256 deadline) external view returns (string memory);

  function batchTransfer(bytes[] calldata data, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

  function quoteUSDCToETH(uint256 percent)
    external
    returns (uint256 expectedOutput, uint256 amountIn, uint256 amountNoSwap);

  function convertUSDCToETHAndSend(uint256 percent, address recipient) external;

  function getConvertUSDCToETHAndSendPermitMessage(uint256 percent, address recipient, uint256 deadline)
    external
    view
    returns (string memory);

  function convertUSDCToETHAndSend(uint256 percent, address recipient, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
    external;
}
