// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import "../src/GiftedBox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../src/UnifiedStore.sol";
import "../src/Vault.sol";

contract UpgradeSwapGiftedBox is Script {
  GiftedBox public newGiftedBox;
  GiftedAccount public newGiftedAccount;
  ERC1967Proxy public proxy;
  UnifiedStore public unifiedStore;

  function run() public {
    address deployer = getAddressFromConfig("deployer");
    vm.startBroadcast(deployer);

    address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
    unifiedStore = UnifiedStore(unifiedStoreAddress);

    address newGiftedBoxImplementation = address(new GiftedBox());
    unifiedStore.setAddress("GiftedBoxImplementation", newGiftedBoxImplementation);
    address proxyAddress = unifiedStore.getAddress("GiftedBox");
    proxy = ERC1967Proxy(payable(proxyAddress));

    GiftedBox existingImplementation = GiftedBox(address(proxy));
    if (address(existingImplementation) != newGiftedBoxImplementation) {
      UUPSUpgradeable(address(proxy)).upgradeToAndCall(newGiftedBoxImplementation, "");
      console.log("GiftedBox upgraded to new implementation:", newGiftedBoxImplementation);
    } else {
      console.log("GiftedBox is already up to date");
    }
    unifiedStore.setAddress("GiftedBoxImplementation", newGiftedBoxImplementation);

    address newGiftedAccountImplementation = address(new GiftedAccount());
    unifiedStore.setAddress("GiftedAccountImplementation", newGiftedAccountImplementation);
    console.log("UnifiedStore set new GiftedAccount implementation:", newGiftedAccountImplementation);

    GiftedAccountGuardian guardian = new GiftedAccountGuardian();
    guardian.setGiftedAccountImplementation(newGiftedAccountImplementation);
    console.log("GiftedAccountGuardian set new GiftedAccount implementation:", newGiftedAccountImplementation);

    guardian.setUnifiedStore(unifiedStoreAddress);
    console.log("GiftedAccountGuardian set UnifiedStore:", unifiedStoreAddress);

    address manager = getAddressFromConfig("manager");
    guardian.setExecutor(manager, true);

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
