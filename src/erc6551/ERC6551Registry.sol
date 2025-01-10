// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IERC6551Registry.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
import { L2ContractHelper } from "@matterlabs/zksync-contracts/l2/contracts/L2ContractHelper.sol";
import { IContractDeployer } from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IContractDeployer.sol";
import "forge-std/Test.sol";

contract ERC6551Registry is IERC6551Registry, Test {
    function createAccount(
        bytes32 bytecodeHash,
        bytes32 salt,
        bytes calldata initData
    ) external returns (address accountAddress) {
        address newAccount = account(bytecodeHash, salt, initData);

        if (newAccount.code.length == 0) {
            emit log_named_bytes32("Creating account with bytecode hash", bytecodeHash);
            emit log_named_bytes32("Salt", salt);
            emit log_named_bytes("Init data", initData);

            (bool success, bytes memory returnData) = SystemContractsCaller.systemCallWithReturndata(
                uint32(gasleft()),
                address(DEPLOYER_SYSTEM_CONTRACT),
                uint128(0),  // No value needed for deployment
                abi.encodeCall(
                    IContractDeployer.create2,
                    (salt, bytecodeHash, bytes(""))
                )
            );

            if (!success) {
                emit log_named_bytes("Deployment failed with data", returnData);
                revert AccountCreationFailed();
            }

            // Verify the account was created
            newAccount = account(bytecodeHash, salt, initData);
            if (newAccount.code.length == 0) {
                emit log_string("Account deployment verification failed");
                revert AccountCreationFailed();
            }

            if (initData.length != 0) {
                (bool successInit,) = newAccount.call(initData);
                if (!successInit) revert InitializationFailed();
            }

            emit AccountCreated(newAccount, bytecodeHash, salt);
            accountAddress = newAccount;
        } else {
            accountAddress = newAccount;
        }
    }

    function account(
        bytes32 bytecodeHash,
        bytes32 salt,
        bytes calldata initData
    ) public view returns (address accountAddress) {
        accountAddress = IContractDeployer(DEPLOYER_SYSTEM_CONTRACT).getNewAddressCreate2(
            address(this),
            bytecodeHash,
            salt,
            initData
        );
    }
}
