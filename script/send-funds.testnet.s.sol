// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import "../src/mocks/MockERC20.sol";
import "../src/UnifiedStore.sol";

contract SendFundsTestnet is Script {
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

  uint256 constant USDT_AMOUNT = 10000 ether;
  uint256 constant USDC_AMOUNT = 10000 ether;
  uint256 constant WBTC_AMOUNT = 10 ether;

  function run() public {
    deployer = getAddressFromConfig("deployer");
    vm.startBroadcast(deployer);

    // Get token addresses from UnifiedStore
    address unifiedStoreAddress = getAddressFromConfig("UnifiedStore");
    unifiedStore = UnifiedStore(unifiedStoreAddress);
    address usdtAddress = unifiedStore.getAddress("TOKEN_USDT");
    address usdcAddress = unifiedStore.getAddress("TOKEN_USDC");
    address wbtcAddress = unifiedStore.getAddress("TOKEN_WBTC");

    mockUSDT = MockERC20(usdtAddress);
    mockUSDC = MockERC20(usdcAddress);
    mockWBTC = MockERC20(wbtcAddress);

    checkAndMint(mockUSDT, USDT_AMOUNT);
    checkAndMint(mockUSDC, USDC_AMOUNT);
    checkAndMint(mockWBTC, WBTC_AMOUNT);

    vm.stopBroadcast();
  }

  function checkAndMint(MockERC20 token, uint256 targetAmount) internal {
    uint256 threshold = (targetAmount * 60) / 100; // 60% of target amount

    for (uint256 i = 0; i < USERS.length; i++) {
      address user = USERS[i];
      uint256 balance = token.balanceOf(user);

      if (balance <= threshold) {
        uint256 amountToMint = targetAmount - balance;
        token.mint(user, amountToMint);
        console.log("Minted %s %s to %s", amountToMint, token.symbol(), user);
      } else {
        console.log("Skipped minting %s for %s, balance sufficient", token.symbol(), user);
      }
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
