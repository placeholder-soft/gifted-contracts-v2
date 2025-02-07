// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/erc6551/ERC6551Registry.sol";
import "../src/GiftedAccount.sol";
import "../src/zksync/ZKERC1967Factory.sol";

contract ERC6551RegistryTest is Test {
    ERC6551Registry public registry;
    GiftedAccount public implementation;
    bytes32 public bytecodeHash;

    function setUp() public {
        // Deploy the registry
        registry = new ERC6551Registry();
        emit log_named_address("Registry address", address(registry));

        // Deploy the implementation
        implementation = new GiftedAccount();
        emit log_named_address("Implementation address", address(implementation));

        string memory artifact = vm.readFile(
            "zkout/GiftedAccount.sol/GiftedAccount.json"
        );
        bytecodeHash = vm.parseJsonBytes32(artifact, ".hash");
        emit log_named_bytes32("Bytecode hash", bytecodeHash);
    }

    function test_CreateAccount() public {
        emit log_string("Starting account creation test");

        bytes32 salt = bytes32(uint256(0));
        address account = registry.createAccount(address(implementation), bytecodeHash, salt, "");
        emit log_named_address("Account address", account);
    }

    function test_DifferentSaltsCreateDifferentAddresses() public {
        bytes32 salt1 = bytes32(uint256(1));
        bytes32 salt2 = bytes32(uint256(2));

        address account1 = registry.account(bytecodeHash, salt1);
        address account2 = registry.account(bytecodeHash, salt2);

        assertNotEq(account1, account2, "Different salts should create different addresses");
    }

    function test_SameParametersCreateSameAddress() public {
        bytes32 salt = bytes32(uint256(1));

        address account1 = registry.account(bytecodeHash, salt);
        address account2 = registry.account(bytecodeHash, salt);

        assertEq(account1, account2, "Same parameters should create same address");
    }

    function test_CreateMultipleAccounts() public {
        for(uint256 i = 1; i <= 3; i++) {
            bytes32 salt = bytes32(i);
            address deployedAccount = registry.createAccount(address(implementation), bytecodeHash, salt, "");

            assertTrue(deployedAccount != address(0), "Account should be deployed");
            assertTrue(deployedAccount.code.length > 0, "Account should have code");
        }
    }
}
