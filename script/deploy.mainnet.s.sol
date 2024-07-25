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

contract DeployMainnet is Script {
    MockERC721 internal mockERC721;
    MockERC1155 internal mockERC1155;
    GiftedBox internal giftedBox;
    ERC6551Registry internal registry;
    GiftedAccountGuardian internal guardian;
    GiftedAccount internal giftedAccount;
    Vault public vault;
    GasSponsorBook public sponsorBook;
    UnifiedStore public unifiedStore;

    address public gasRelayer =
        address(0xe335Cf211aA52f3a84257F61dde34C3BDFced560);
    address public deployer =
        address(0xf53f105E90b3e9Ea928926A5A78E921D8168e213);


    function run() public {
        update_fee_ticket();
    }

    function add_fund_vault() public {
        vm.startBroadcast(deployer);
        vault = Vault(0xF74d7124909f634B38799d871fD9f633b223b2C6);
        vault.transferIn{value: 0.01 ether}(address(0), deployer, 0.01 ether);
        vm.stopBroadcast();
    }

    function update_fee_ticket() public {
        vm.startBroadcast(deployer);
        sponsorBook = GasSponsorBook(0xbec73A3ed80216efbc5203DC014F183F582E97c0);
        sponsorBook.setFeePerSponsorTicket(0.0000006 ether);
        vm.stopBroadcast();
    }

    function deploy_artwork() internal {
        vm.startBroadcast();
        mockERC721 = new MockERC721();
        mockERC721.setBaseURI("https://app.gifted.art/api/nfts/");

        mockERC1155 = new MockERC1155();
        mockERC1155.setURI("https://app.gifted.art/api/nfts/");
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


        unifiedStore = new UnifiedStore();

        string[] memory keys = new string[](6);
        address[] memory addresses = new address[](6);
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

        unifiedStore.setAddresses(keys, addresses);
        
        vm.stopBroadcast();
    }
}
