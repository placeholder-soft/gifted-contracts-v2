// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/erc6551/ERC6551Registry.sol";
import "../src/GiftedAccount.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/Constants.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/Utils.sol";
import "@matterlabs/zksync-contracts/l2/system-contracts/libraries/EfficientCall.sol";

contract ERC6551RegistryTest is Test {
    ERC6551Registry public registry;
    GiftedAccount public implementation;
    bytes32 public bytecodeHash;

    function setUp() public {
        registry = new ERC6551Registry();
        emit log_named_address("Registry address", address(registry));
        implementation = new GiftedAccount();
        emit log_named_address("GiftedAccount address", address(implementation));

        // Read bytecode hash from artifact file
        string memory artifact = vm.readFile(
            "zkout/GiftedAccount.sol/GiftedAccount.json"
        );
        bytecodeHash = vm.parseJsonBytes32(artifact, ".hash");
    }

    function test_CreateAccount() public {
        emit log_string("Starting account creation test");
        emit log_named_bytes32("Bytecode hash", bytecodeHash);

        // Empty init data since constructor doesn't take parameters in zkEVM
        bytes memory initData = "";

        // Use a simple salt value
        bytes32 salt = bytes32(uint256(1));
        emit log_named_bytes32("Salt", salt);

        emit log_named_address("Registry address", address(registry));
        emit log_named_address("Implementation address", address(implementation));

        // Try to compute the account address first
        address computedAddress = registry.account(bytecodeHash, salt, initData);
        emit log_named_address("Computed account address", computedAddress);

        // Deploy the account
        try registry.createAccount(
            bytecodeHash,
            salt,
            initData
        ) returns (address deployedAccount) {
            emit log_named_address("Account deployed successfully at", deployedAccount);
            assertNotEq(deployedAccount, address(0));

            // Initialize the account after creation with all required parameters
            vm.startPrank(deployedAccount);
            try GiftedAccount(payable(deployedAccount)).initialize(
                address(0),  // unifiedStore
                block.chainid,  // erc6551ChainId
                address(this),  // erc6551Contract
                1  // erc6551TokenId
            ) {
                emit log_string("Account initialized successfully");
            } catch Error(string memory reason) {
                emit log_named_string("Account initialization failed with reason", reason);
                revert(reason);
            } catch (bytes memory lowLevelData) {
                emit log_string("Account initialization failed with low level error");
                emit log_bytes(lowLevelData);
                revert("Account initialization failed with low level error");
            }
            vm.stopPrank();
        } catch Error(string memory reason) {
            emit log_named_string("Account creation failed with reason", reason);
            revert(reason);
        } catch (bytes memory lowLevelData) {
            emit log_string("Account creation failed with low level error");
            emit log_bytes(lowLevelData);
            revert("Account creation failed with low level error");
        }
    }

    function test_Account() public view {
        bytes memory initData = "";
        bytes32 salt = bytes32(uint256(1));

        address registryComputedAddress = registry.account(
            bytecodeHash,
            salt,
            initData
        );

        assert(registryComputedAddress != address(0));
    }

    function test_DifferentSaltsCreateDifferentAddresses() public view {
        bytes memory initData = "";
        bytes32 salt1 = bytes32(uint256(1));
        bytes32 salt2 = bytes32(uint256(2));

        address account1 = registry.account(bytecodeHash, salt1, initData);
        address account2 = registry.account(bytecodeHash, salt2, initData);

        assert(account1 != account2);
    }

    function test_SameParametersCreateSameAddress() public view {
        bytes memory initData = "";
        bytes32 salt = bytes32(uint256(1));

        address account1 = registry.account(bytecodeHash, salt, initData);
        address account2 = registry.account(bytecodeHash, salt, initData);

        assert(account1 == account2);
    }
}
