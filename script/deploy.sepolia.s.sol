// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {GiftedBox} from "../src/GiftedBox.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/mocks/MockERC721.sol";
import "../src/mocks/MockERC1155.sol";
import "../src/GiftedAccount.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import "erc6551/ERC6551Registry.sol";
import "../src/GasSponsorBook.sol";
import "../src/UnifiedStore.sol";
import "../src/Vault.sol";

contract DeploySepolia is Script {
    MockERC721 internal mockERC721;
    MockERC1155 internal mockERC1155;
    GiftedBox internal giftedBox;
    ERC6551Registry internal registry;
    GiftedAccountGuardian internal guardian;
    GiftedAccount internal giftedAccount;
    Vault public vault;
    GasSponsorBook public sponsorBook;
    address public gasRelayer =
        address(0x08E3dBFCF164Df355E36B65B4e71D9E66483e083);
    address public deployer =
        address(0xB7d030F7c6406446e703E73B3d1dd8611A2D87b6);

    function run() public {
        deploy_contracts();
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
        guardian = new GiftedAccountGuardian();
        GiftedAccount giftedAccountImpl = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(giftedAccountImpl));

        GiftedAccountProxy accountProxy = new GiftedAccountProxy(
            address(guardian)
        );
        giftedAccount = GiftedAccount(payable(address(accountProxy)));

        registry = new ERC6551Registry();

        address implementation = address(new GiftedBox());
        bytes memory data = abi.encodeCall(GiftedBox.initialize, deployer);
        address proxy = address(new ERC1967Proxy(implementation, data));
        giftedBox = GiftedBox(proxy);

        giftedBox.setAccountImpl(payable(address(giftedAccount)));
        giftedBox.setRegistry(address(registry));
        giftedBox.setAccountGuardian(address(guardian));
        giftedBox.grantRole(giftedBox.CLAIMER_ROLE(), gasRelayer);

        vault = new Vault();
        vault.initialize(deployer);
        sponsorBook = new GasSponsorBook();
        vault.grantRole(vault.CONTRACT_ROLE(), address(sponsorBook));

        sponsorBook.setVault(vault);
        giftedBox.setGasSponsorBook(address(sponsorBook));
        sponsorBook.grantRole(sponsorBook.SPONSOR_ROLE(), address(giftedBox));
        sponsorBook.grantRole(sponsorBook.CONSUMER_ROLE(), gasRelayer);
        vm.stopBroadcast();
    }
}
