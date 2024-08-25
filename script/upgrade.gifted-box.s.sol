// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "../src/GiftedBox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../src/UnifiedStore.sol";

contract UpgradeGiftedBox is Script {
    GiftedBox public newImplementation;
    ERC1967Proxy public proxy;
    UnifiedStore public unifiedStore;

    function run() public {
        address deployer = getAddressFromConfig("deployer");
        vm.startBroadcast(deployer);

        address newImplementationAddress = deploy_new_implementation();
        upgrade_proxy(newImplementationAddress);
        set_new_implementation_address(newImplementationAddress);

        vm.stopBroadcast();
    }

    function deploy_new_implementation() internal returns (address) {
        newImplementation = new GiftedBox();
        return address(newImplementation);
    }

    function upgrade_proxy(address newImplementationAddress) internal {
        address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
        unifiedStore = UnifiedStore(unifiedStoreAddress);

        address proxyAddress = unifiedStore.getAddress("GiftedBox");
        proxy = ERC1967Proxy(payable(proxyAddress));

        GiftedBox existingImplementation = GiftedBox(address(proxy));
        if (address(existingImplementation) != newImplementationAddress) {
            UUPSUpgradeable(address(proxy)).upgradeToAndCall(newImplementationAddress, "");
            console.log("GiftedBox upgraded to new implementation:", newImplementationAddress);
        } else {
            console.log("GiftedBox is already up to date");
        }
    }

    function set_new_implementation_address(address newImplementationAddress) internal {
        address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
        unifiedStore = UnifiedStore(unifiedStoreAddress);

        unifiedStore.setAddress("GiftedBoxImplementation", newImplementationAddress);
        console.log("New GiftedBox implementation address set in UnifiedStore:", newImplementationAddress);
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