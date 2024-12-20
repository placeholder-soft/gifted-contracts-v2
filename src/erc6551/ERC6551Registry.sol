// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IERC6551Registry.sol";
import "./ERC6551BytecodeLib.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
import { L2ContractHelper } from "@matterlabs/zksync-contracts/l2/contracts/L2ContractHelper.sol";
import { console } from "forge-std/console.sol";
contract ERC6551Registry is IERC6551Registry {
  function createAccount(
    address implementation,
    uint256 chainId,
    address tokenContract,
    uint256 tokenId,
    uint256 salt,
    bytes calldata initData
  ) external returns (address accountAddress) {
    bytes memory creationCode =
    ERC6551BytecodeLib.getCreationCode(implementation, bytes32(salt), chainId, tokenContract, tokenId);
    console.logBytes(creationCode);
    bytes32 bytecodeHash = keccak256(creationCode);
    address newAccount = account(implementation, chainId, tokenContract, tokenId, salt);
    console.log("newAccount", newAccount);

    if (newAccount.code.length == 0) {
      (bool success, bytes memory returnData) = SystemContractsCaller.systemCallWithReturndata(
        uint32(gasleft()),
        address(DEPLOYER_SYSTEM_CONTRACT),
        uint128(0),
        abi.encodeCall(
          DEPLOYER_SYSTEM_CONTRACT.create2, (bytes32(salt), bytecodeHash, abi.encode(chainId, tokenContract, tokenId))
        )
      );
      console.logBytes(returnData);
      if (!success) revert AccountCreationFailed();

      address createdAccount;
      assembly {
          createdAccount := create2(0, add(creationCode, 32), mload(creationCode), salt)
      }
      console.log("createdAccount", createdAccount);
      if (initData.length != 0) {
        (bool successInit,) = createdAccount.call(initData);
        if (!successInit) revert InitializationFailed();
      }

      emit AccountCreated(newAccount, implementation, salt, chainId, tokenContract, tokenId);

      accountAddress = newAccount;
      // accountAddress = abi.decode(returnData, (address));
    } else {
      console.log("newAccount already exists");
      accountAddress = newAccount;
    }
        //     assembly {
        //     // Memory Layout:
        //     // ----
        //     // 0x00   0xff                           (1 byte)
        //     // 0x01   registry (address)             (20 bytes)
        //     // 0x15   salt (bytes32)                 (32 bytes)
        //     // 0x35   Bytecode Hash (bytes32)        (32 bytes)
        //     // ----
        //     // 0x55   ERC-1167 Constructor + Header  (20 bytes)
        //     // 0x69   implementation (address)       (20 bytes)
        //     // 0x5D   ERC-1167 Footer                (15 bytes)
        //     // 0x8C   salt (uint256)                 (32 bytes)
        //     // 0xAC   chainId (uint256)              (32 bytes)
        //     // 0xCC   tokenContract (address)        (32 bytes)
        //     // 0xEC   tokenId (uint256)              (32 bytes)

        //     // Silence unused variable warnings
        //     pop(chainId)

        //     // Copy bytecode + constant data to memory
        //     calldatacopy(0x8c, 0x24, 0x80) // salt, chainId, tokenContract, tokenId
        //     mstore(0x6c, 0x5af43d82803e903d91602b57fd5bf3) // ERC-1167 footer
        //     mstore(0x5d, implementation) // implementation
        //     mstore(0x49, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73) // ERC-1167 constructor + header

        //     // Copy create2 computation data to memory
        //     mstore8(0x00, 0xff) // 0xFF
        //     mstore(0x35, keccak256(0x55, 0xb7)) // keccak256(bytecode)
        //     mstore(0x01, shl(96, address())) // registry address
        //     mstore(0x15, salt) // salt

        //     // Compute account address
        //     let computed := keccak256(0x00, 0x55)

        //     // If the account has not yet been deployed
        //     if iszero(extcodesize(computed)) {
        //         // Deploy account contract
        //         let deployed := create2(0, 0x55, 0xb7, salt)

        //         // Revert if the deployment fails
        //         if iszero(deployed) {
        //             mstore(0x00, 0x20188a59) // `AccountCreationFailed()`
        //             revert(0x1c, 0x04)
        //         }

        //         // Store account address in memory before salt and chainId
        //         mstore(0x6c, deployed)

        //         // Emit the ERC6551AccountCreated event
        //         log4(
        //             0x6c,
        //             0x60,
        //             // `ERC6551AccountCreated(address,address,bytes32,uint256,address,uint256)`
        //             0x79f19b3655ee38b1ce526556b7731a20c8f218fbda4a3990b6cc4172fdf88722,
        //             implementation,
        //             tokenContract,
        //             tokenId
        //         )

        //         // Return the account address
        //         return(0x6c, 0x20)
        //     }

        //     // Otherwise, return the computed account address
        //     mstore(0x00, shr(96, shl(96, computed)))
        //     return(0x00, 0x20)
        // }
  }

  function account(address implementation, uint256 chainId, address tokenContract, uint256 tokenId, uint256 salt)
    public
    view
    returns (address accountAddress)
  {
    bytes memory creationCode =
      ERC6551BytecodeLib.getCreationCode(implementation, bytes32(salt), chainId, tokenContract, tokenId);
    bytes32 bytecodeHash = keccak256(creationCode);
    accountAddress = L2ContractHelper.computeCreate2Address(address(this), bytes32(salt), bytecodeHash, 0);
  }
}
