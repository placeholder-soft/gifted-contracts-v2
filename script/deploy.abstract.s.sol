// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { GiftedBox } from "../src/GiftedBox.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/mocks/MockERC721.sol";
import "../src/mocks/MockERC1155.sol";
import "../src/GiftedAccount.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import {ERC6551Registry} from "../src/erc6551/ERC6551Registry.sol";
import "../src/GasSponsorBook.sol";
import "../src/UnifiedStore.sol";
import "../src/Vault.sol";
import "../src/NFTVault.sol";

contract DeploySepolia is Script {
  MockERC721 internal mockERC721;
  MockERC1155 internal mockERC1155;
  GiftedBox internal giftedBox;
  ERC6551Registry internal registry;
  GiftedAccountGuardian internal guardian;
  GiftedAccount internal giftedAccount;
  Vault public vault;
  NFTVault public nftVault;
  GasSponsorBook public sponsorBook;
  UnifiedStore public unifiedStore;
  address internal giftedBoxImplementation;

  address public gasRelayer = address(0x08E3dBFCF164Df355E36B65B4e71D9E66483e083);
  address public deployer = address(0xB7d030F7c6406446e703E73B3d1dd8611A2D87b6);

  uint256 internal currentChainId;

  function run() public {
    // Get current chain ID
    currentChainId = block.chainid;
    console.log("Deploying to chain ID:", currentChainId);

    // deploy_contracts();
    // deploy_artwork();
    // deploy_test();
    vm.startBroadcast(deployer);
    registry = new ERC6551Registry();
    vm.stopBroadcast();
  }

  function deploy_test() internal {
    vm.startBroadcast(deployer);
    unifiedStore = new UnifiedStore();
    vm.stopBroadcast();
  }

  function deploy_artwork() internal {
    vm.startBroadcast();
    mockERC721 = new MockERC721();
    mockERC721.setBaseURI("https://staging.gifted.art/api/nfts/");

    mockERC1155 = new MockERC1155();
    mockERC1155.setURI("https://staging.gifted.art/api/nfts/");
    vm.stopBroadcast();
  }

  function deploy_contracts() internal {
    vm.startBroadcast(deployer);

    // Add validation for deployer address
    require(deployer != address(0), "Deployer address cannot be zero");
    console.log("Deploying contracts with deployer:", deployer);

    unifiedStore = new UnifiedStore();
    // Deploy guardian and log
    guardian = new GiftedAccountGuardian();
    console.log("GiftedAccountGuardian deployed at:", address(guardian));

    // Deploy and set implementation
    GiftedAccount giftedAccountImpl = new GiftedAccount();
    console.log("GiftedAccount implementation deployed at:", address(giftedAccountImpl));

    require(address(guardian) != address(0), "Guardian deployment failed");
    guardian.setGiftedAccountImplementation(address(giftedAccountImpl));
    // guardian.setUnifiedStore(address(unifiedStore));

    // Deploy proxy with validation
    GiftedAccountProxy accountProxy = new GiftedAccountProxy(address(guardian));
    require(address(accountProxy) != address(0), "Proxy deployment failed");
    giftedAccount = GiftedAccount(payable(address(accountProxy)));
    console.log("GiftedAccount proxy deployed at:", address(giftedAccount));

    // Continue with rest of deployments with logging
    registry = new ERC6551Registry();
    console.log("ERC6551Registry deployed at:", address(registry));

    giftedBoxImplementation = address(new GiftedBox());
    console.log("GiftedBox implementation deployed at:", giftedBoxImplementation);

    require(giftedBoxImplementation != address(0), "GiftedBox implementation deployment failed");
    bytes memory data = abi.encodeCall(GiftedBox.initialize, deployer);
    address proxy = address(new ERC1967Proxy(giftedBoxImplementation, data));
    require(proxy != address(0), "GiftedBox proxy deployment failed");
    giftedBox = GiftedBox(proxy);
    console.log("GiftedBox proxy deployed at:", address(giftedBox));

    giftedBox.setAccountImpl(payable(address(giftedAccount)));
    giftedBox.setRegistry(address(registry));
    giftedBox.setUnifiedStore(address(unifiedStore));
    giftedBox.grantRole(giftedBox.CLAIMER_ROLE(), gasRelayer);

    vault = new Vault();
    vault.initialize(deployer);
    sponsorBook = new GasSponsorBook();
    vault.grantRole(vault.CONTRACT_ROLE(), address(sponsorBook));

    sponsorBook.setVault(vault);
    giftedBox.setGasSponsorBook(address(sponsorBook));
    sponsorBook.grantRole(sponsorBook.SPONSOR_ROLE(), address(giftedBox));
    sponsorBook.grantRole(sponsorBook.CONSUMER_ROLE(), gasRelayer);

    nftVault = new NFTVault();
    nftVault.grantManagerRole(gasRelayer);


    string[] memory keys = new string[](7);
    address[] memory addresses = new address[](7);
    keys[0] = "GiftedAccountGuardian";
    addresses[0] = address(guardian);

    keys[1] = "GiftedAccount";
    addresses[1] = address(giftedAccount);

    keys[2] = "GiftedBox";
    addresses[2] = address(giftedBox);

    keys[3] = "Vault";
    addresses[3] = address(vault);

    keys[4] = "GasSponsorBook";
    addresses[4] = address(sponsorBook);

    keys[5] = "ERC6551Registry";
    addresses[5] = address(registry);

    keys[6] = "NFTVault";
    addresses[6] = address(nftVault);

    unifiedStore.setAddresses(keys, addresses);

    vm.stopBroadcast();
  }
}
