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

    address public gasRelayer =
        address(0x08E3dBFCF164Df355E36B65B4e71D9E66483e083);
    address public deployer =
        address(0xB7d030F7c6406446e703E73B3d1dd8611A2D87b6);

    function run() public {
        deploy_contracts();
        deploy_artwork();
    }

    function deploy_test() internal {
        vm.startBroadcast(deployer);
        unifiedStore = new UnifiedStore();
        vm.stopBroadcast(); 
    }

    function set_sponsor_ticket() internal {
        vm.startBroadcast(deployer);

        sponsorBook = GasSponsorBook(
            address(0x11d0E669D24F682F7690fDf5407B20287050a74A)
        );

        sponsorBook.setFeePerSponsorTicket(0.000001 ether);

        vm.stopBroadcast();
    }

    function deploy_UnifiedStore() internal {
        vm.startBroadcast(deployer);
        unifiedStore = new UnifiedStore();

        string[] memory keys = new string[](6);
        address[] memory addresses = new address[](6);
        keys[0] = "GiftedAccountGuardian";
        addresses[0] = address(0x40Dba44E7d95affF4BC8afa349393f26c8f61da6);

        keys[1] = "GiftedAccount";
        addresses[1] = address(0xeDc1452817e8bDAe482D6D026c07C77f2053b693);

        keys[2] = "GiftedBox";
        addresses[2] = address(0x384C26db13269BB3215482F9B932371e4803B29f);

        keys[3] = "Vault";
        addresses[3] = address(0x95c566AB7A776314424364D1e2476399167b916c);

        keys[4] = "GasSponsorBook";
        addresses[4] = address(0xa80F5B8d1126D7A2eB1cE271483cF70bBb4e6e0A);

        keys[5] = "ERC6551Registry";
        addresses[5] = address(0x1ffdaf9a2561c0CbCC13F3fca6381A0E060Af66E);

        for (uint i = 0; i < addresses.length; i++) {
            uint32 size;
            address addr = addresses[i];
            assembly {
                size := extcodesize(addr)
            }
            require(
                size > 0,
                string(
                    abi.encodePacked(
                        "Address ",
                        keys[i],
                        " does not contain code"
                    )
                )
            );
        }

        unifiedStore.setAddresses(keys, addresses);

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

        nftVault = new NFTVault();
        nftVault.grantManagerRole(gasRelayer);

        unifiedStore = new UnifiedStore();

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
