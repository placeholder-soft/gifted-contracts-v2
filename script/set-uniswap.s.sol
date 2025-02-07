// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import { Script, console } from "forge-std/Script.sol";
// import "../src/GiftedBox.sol";
// import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
// import "../src/UnifiedStore.sol";
// import "../src/Vault.sol";

// contract UpgradeGiftedBox is Script {
//   GiftedBox public newGiftedBox;
//   GiftedAccount public newGiftedAccount;
//   ERC1967Proxy public proxy;
//   UnifiedStore public unifiedStore;

//   function run() public {
//     address deployer = getAddressFromConfig("deployer");
//     vm.startBroadcast(deployer);

//     unifiedStore = UnifiedStore(getAddressFromConfig("UnifiedStore"));

//     string[] memory keys = new string[](4);
//     address[] memory values = new address[](4);
//     keys[0] = "UNISWAP_ROUTER";
//     keys[1] = "UNISWAP_QUOTER";
//     keys[2] = "TOKEN_WETH";
//     keys[3] = "TOKEN_USDC";

//     if (block.chainid == 11155111) {
//       values[0] = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;
//       values[1] = 0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3;
//       values[2] = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
//       values[3] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
//     } else if (block.chainid == 1) {
//       values[0] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
//       values[1] = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
//     } else if (block.chainid == 8453) {
//       values[0] = 0x2626664c2603336E57B271c5C0b26F421741e481;
//       values[1] = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;
//       values[2] = 0x4200000000000000000000000000000000000006;
//       values[3] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
//     } else if (block.chainid == 84532) {
//       values[0] = 0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4;
//       values[1] = 0xC5290058841028F1614F3A6F0F5816cAd0df5E27;
//       values[2] = 0x4200000000000000000000000000000000000006;
//     } else if (block.chainid == 42161) {
//       values[0] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
//       values[1] = 0x61fFE014bA17989E743c5F6cB21bF9697530B21e;
//       values[2] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
//       values[3] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
//     } else if (block.chainid == 421614) {
//       values[0] = 0x101F443B4d1b059569D643917553c771E1b9663E;
//       values[1] = 0x2779a0CC1c3e0E44D2542EC3e79e3864Ae93Ef0B;
//     }

//     unifiedStore.setAddresses(keys, values);

//     vm.stopBroadcast();
//   }

//   function getAddressFromConfig(string memory key) internal view returns (address) {
//     string memory env = vm.envString("DEPLOY_ENV");
//     require(bytes(env).length > 0, "DEPLOY_ENV must be set");
//     string memory root = vm.projectRoot();
//     string memory path = string.concat(root, "/config/", env, "_addresses.json");
//     string memory json = vm.readFile(path);
//     bytes memory addressBytes = vm.parseJson(json, string.concat(".", vm.toString(block.chainid), ".", key));
//     return abi.decode(addressBytes, (address));
//   }
// }
