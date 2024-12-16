// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import "../src/mocks/MockERC20.sol";
import "../src/UnifiedStore.sol";

contract DeployMockERC20Sepolia is Script {
  MockERC20 public mockUSDT;
  MockERC20 public mockUSDC;
  MockERC20 public mockWBTC;
  UnifiedStore public unifiedStore;

  address public deployer;
  address[4] public USERS = [
    0x4F88F1014Dd6Ca0507780380111c098BeE6b87e6,
    0xC31f6b8133d618aD2ff1AC5fAA3Fc4B20557B901,
    0x66E675533020c3CDeE2F33E372320B7e2692211e,
    0x8c4Eb6988A199DAbcae0Ce31052b3f3aC591787e
  ];

  function run() public {
    deployer = getAddressFromConfig("deployer");
    vm.startBroadcast(deployer);

    // Deploy MockUSDT
    mockUSDT = new MockERC20(deployer, "Tether USD", "USDT");
    mintToAll(mockUSDT, 10000 ether); // USDT typically has 6 decimals

    // Deploy MockUSDC
    mockUSDC = new MockERC20(deployer, "USD Coin", "USDC");
    mintToAll(mockUSDC, 10000 ether); // USDC typically has 6 decimals

    // Deploy MockWBTC
    mockWBTC = new MockERC20(deployer, "Wrapped BTC", "WBTC");
    mintToAll(mockWBTC, 10000 ether); // WBTC typically has 8 decimals

    // // Update UnifiedStore with new token addresses
    // address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
    // unifiedStore = UnifiedStore(unifiedStoreAddress);
    // string[] memory keys = new string[](3);
    // address[] memory addresses = new address[](3);

    // keys[0] = "TOKEN_USDT";
    // addresses[0] = address(mockUSDT);

    // keys[1] = "TOKEN_USDC";
    // addresses[1] = address(mockUSDC);

    // keys[2] = "TOKEN_WBTC";
    // addresses[2] = address(mockWBTC);

    // unifiedStore.setAddresses(keys, addresses);

    vm.stopBroadcast();

    // Log the deployed contract addresses
    console.log("MockUSDT deployed at:", address(mockUSDT));
    console.log("MockUSDC deployed at:", address(mockUSDC));
    console.log("MockWBTC deployed at:", address(mockWBTC));
    console.log("UnifiedStore updated with new token addresses");
  }

  function mintToAll(MockERC20 token, uint256 amount) internal {
    // Mint to deployer
    token.mint(deployer, amount);

    // Mint to specified users
    for (uint256 i = 0; i < USERS.length; i++) {
      token.mint(USERS[i], amount);
    }
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
