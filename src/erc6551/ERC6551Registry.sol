// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IERC6551Registry.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
import { L2ContractHelper } from "@matterlabs/zksync-contracts/l2/contracts/L2ContractHelper.sol";
import { IContractDeployer } from "@matterlabs/zksync-contracts/l2/system-contracts/interfaces/IContractDeployer.sol";
import { console } from "forge-std/console.sol";

contract ERC6551Registry is IERC6551Registry {
    function createAccount(
        bytes32 bytecodeHash,
        uint256 salt,
        bytes calldata initData
    ) external returns (address accountAddress) {
        address newAccount = account(bytecodeHash, salt, initData);
        console.log("newAccount", newAccount);

        if (newAccount.code.length == 0) {
            (bool success, bytes memory returnData) = SystemContractsCaller.systemCallWithReturndata(
                uint32(gasleft()),
                address(DEPLOYER_SYSTEM_CONTRACT),
                uint128(0),
                abi.encodeCall(
                    IContractDeployer.create2,
                    (bytes32(salt), bytecodeHash, initData)
                )
            );

            if (!success) revert AccountCreationFailed();

            if (initData.length != 0) {
                (bool successInit,) = newAccount.call(initData);
                if (!successInit) revert InitializationFailed();
            }

            emit AccountCreated(newAccount, bytecodeHash, bytes32(salt));
            accountAddress = newAccount;
        } else {
            console.log("newAccount already exists");
            accountAddress = newAccount;
        }
    }

    function account(
        bytes32 bytecodeHash,
        uint256 salt,
        bytes calldata initData
    ) public view returns (address accountAddress) {
        accountAddress = IContractDeployer(DEPLOYER_SYSTEM_CONTRACT).getNewAddressCreate2(
            address(this),
            bytecodeHash,
            bytes32(salt),
            initData
        );
    }
}
