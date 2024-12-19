// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IERC6551Registry.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";


contract ERC6551Registry is IERC6551Registry {
  error InitializationFailed();

function createAccount(
    bytes32 bytecodeHash,
    bytes32 salt,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId
  ) external returns (address accountAddress) {
    address newAccount = account(bytecodeHash, salt, chainId, tokenContract, tokenId);
    if (newAccount.code.length == 0) {
      (bool success, bytes memory returnData) = SystemContractsCaller
        .systemCallWithReturndata(
          uint32(gasleft()),
          address(DEPLOYER_SYSTEM_CONTRACT),
          uint128(0),
          abi.encodeCall(
            DEPLOYER_SYSTEM_CONTRACT.create2,
            (salt, bytecodeHash, abi.encode(chainId, tokenContract, tokenId))
          )
        );
      if (!success) { revert AccountCreationFailed(); }

      emit ERC6551AccountCreated(newAccount, bytecodeHash, salt, chainId, tokenContract, tokenId);

      accountAddress = abi.decode(returnData, (address));
    } else {
      accountAddress = newAccount;
    }
  }

  function account(
    bytes32 bytecodeHash,
    bytes32 salt,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId
  ) public returns (address accountAddress) {
    (bool success, bytes memory returnData) = SystemContractsCaller
      .systemCallWithReturndata(
        uint32(gasleft()),
        address(DEPLOYER_SYSTEM_CONTRACT),
        uint128(0),
        abi.encodeCall(
          DEPLOYER_SYSTEM_CONTRACT.getNewAddressCreate2,
          (msg.sender, bytecodeHash, salt, abi.encode(chainId, tokenContract, tokenId))
        )
      );
    if (!success) { revert AccountComputeFailed(); }

    accountAddress = abi.decode(returnData, (address));
  }
}
