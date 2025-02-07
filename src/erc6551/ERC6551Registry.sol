// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interfaces/IERC6551Registry.sol";
import {ZKERC1967Factory} from "../zksync/ZKERC1967Factory.sol";

contract ERC6551Registry is IERC6551Registry {
    ZKERC1967Factory public immutable factory;

    constructor() {
        factory = new ZKERC1967Factory();
    }

    function createAccount(
        address implementation,
        bytes32 bytecodeHash,
        bytes32 salt,
        bytes calldata initData
    ) external returns (address accountAddress) {
        address existingAccount = account(bytecodeHash, salt);

        if (existingAccount.code.length == 0) {
            // Deploy proxy pointing to the implementation
            accountAddress = factory.deployProxyDeterministic(
                implementation,
                msg.sender, // Admin is the caller
                salt
            );

            // Initialize if needed
            if (initData.length > 0) {
                (bool success,) = accountAddress.call(initData);
                if (!success) revert InitializationFailed();
            }

            emit AccountCreated(accountAddress, bytecodeHash, salt);
        } else {
            accountAddress = existingAccount;
        }
    }

    function account(
        bytes32 bytecodeHash,
        bytes32 salt
    ) public view returns (address) {
        return factory.predictDeterministicAddress(bytecodeHash, salt);
    }
}
