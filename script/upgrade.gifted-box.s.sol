// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import "../src/GiftedBox.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../src/UnifiedStore.sol";
import "../src/Vault.sol";

contract UpgradeGiftedBox is Script {
  GiftedBox public newGiftedBox;
  GiftedAccount public newGiftedAccount;
  ERC1967Proxy public proxy;
  UnifiedStore public unifiedStore;

  function run() public {
    address deployer = getAddressFromConfig("deployer");
    vm.startBroadcast(deployer);

    address newGiftedBoxImplementation = deploy_new_gifted_box();
    upgrade_gifted_box(newGiftedBoxImplementation);
    set_new_gifted_box_address(newGiftedBoxImplementation);

    proxy = ERC1967Proxy(payable(getAddressFromConfig("GiftedBox")));

    // address newGiftedAccountImplementation = deploy_new_gifted_account();
    // set_new_gifted_account_address(newGiftedAccountImplementation);

    // address guardianAddress = getAddressFromConfig("GiftedAccountGuardian");
    // GiftedAccountGuardian guardian = GiftedAccountGuardian(guardianAddress);
    // guardian.setGiftedAccountImplementation(newGiftedAccountImplementation);
    // console.log("GiftedAccountGuardian set new GiftedAccount implementation:", newGiftedAccountImplementation);

    // address manager = getAddressFromConfig("manager");
    // guardian.setExecutor(manager, true);


    GiftedBox(address(proxy)).setBaseURI("https://rest-api.gifted.art/api/v1/gifts/metadata/base/");

    console.log("GiftedBox baseURI set to:", GiftedBox(address(proxy)).baseURI());

    vm.stopBroadcast();
  }

  function deploy_new_gifted_box() internal returns (address) {
    newGiftedBox = new GiftedBox();
    return address(newGiftedBox);
  }

  function deploy_new_gifted_account() internal returns (address) {
    newGiftedAccount = new GiftedAccount();
    return address(newGiftedAccount);
  }

  function upgrade_gifted_box(address newGiftedBoxImplementation) internal {
    address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
    unifiedStore = UnifiedStore(unifiedStoreAddress);

    address proxyAddress = unifiedStore.getAddress("GiftedBox");
    proxy = ERC1967Proxy(payable(proxyAddress));

    GiftedBox existingImplementation = GiftedBox(address(proxy));
    if (address(existingImplementation) != newGiftedBoxImplementation) {
      UUPSUpgradeable(address(proxy)).upgradeToAndCall(newGiftedBoxImplementation, "");
      console.log("GiftedBox upgraded to new implementation:", newGiftedBoxImplementation);
    } else {
      console.log("GiftedBox is already up to date");
    }
  }

  function set_new_gifted_box_address(address newGiftedBoxImplementation) internal {
    address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
    unifiedStore = UnifiedStore(unifiedStoreAddress);

    unifiedStore.setAddress("GiftedBoxImplementation", newGiftedBoxImplementation);
    console.log("New GiftedBox implementation address set in UnifiedStore:", newGiftedBoxImplementation);
  }

  function set_new_gifted_account_address(address newGiftedAccountImplementation) internal {
    address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
    unifiedStore = UnifiedStore(unifiedStoreAddress);

    unifiedStore.setAddress("GiftedAccountImplementation", newGiftedAccountImplementation);
    console.log("New GiftedAccount implementation address set in UnifiedStore:", newGiftedAccountImplementation);
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
