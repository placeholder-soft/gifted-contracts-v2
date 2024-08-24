// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/NFTVault.sol";
import "../src/UnifiedStore.sol";

contract DeployVault is Script {
    NFTVault public nftVault;
    UnifiedStore public unifiedStore;

    address public manager;

    function run() public {
        deploy_contracts();
        setup_roles();
        update_unified_store();
    }

    function deploy_contracts() internal {
        vm.startBroadcast(getAddressFromConfig("deployer"));

        nftVault = new NFTVault();

        vm.stopBroadcast();
    }

    function setup_roles() internal {
        vm.startBroadcast(getAddressFromConfig("deployer"));

        manager = getAddressFromConfig("manager");
        nftVault.grantManagerRole(manager);

        vm.stopBroadcast();
    }

    function update_unified_store() internal {
        vm.startBroadcast(getAddressFromConfig("deployer"));

        address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
        unifiedStore = UnifiedStore(unifiedStoreAddress);

        string[] memory keys = new string[](1);
        address[] memory addresses = new address[](1);

        keys[0] = "NFTVault";
        addresses[0] = address(nftVault);

        unifiedStore.setAddresses(keys, addresses);

        vm.stopBroadcast();
    }

    function getAddressFromConfig(string memory key) internal view returns (address) {
        string memory env = vm.envString("DEPLOY_ENV");
        require(bytes(env).length > 0, "DEPLOY_ENV must be set");
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/config/", env, "_addresses.json");
        string memory json = vm.readFile(path);
        bytes memory addressBytes = vm.parseJson(json, string.concat(".", vm.toString(block.chainid), ".", key));
        return abi.decode(addressBytes, (address));
    }
}