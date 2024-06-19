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
    UnifiedStore public unifiedStore;

    address public gasRelayer =
        address(0x08E3dBFCF164Df355E36B65B4e71D9E66483e083);
    address public deployer =
        address(0xB7d030F7c6406446e703E73B3d1dd8611A2D87b6);

    function run() public {
        set_registery_config();
    }

    function set_registery_config() internal {
        vm.startBroadcast(deployer);
        UnifiedStore store = UnifiedStore(0xd62Df558426c7A37DCdA006B83362B610423484b);
        store.setAddress("ERC6551Registry", 0xF0401c57Ff0Cb78Af5340dA8ABf79f7B1D9b4A50);
        vm.stopBroadcast();
    }

    function deploy_UnifiedStore() internal {
        vm.startBroadcast(deployer);
        unifiedStore = new UnifiedStore();

        string[] memory keys = new string[](5);
        address[] memory addresses = new address[](5);
        keys[0] = "GiftedAccountGuardian";
        addresses[0] = address(0x7C9612ed0716CC48474AcB908B4766239709d6A0);

        keys[1] = "GiftedAccount";
        addresses[1] = address(0xB765c1801dB3712d0330b83585496D27Fac01420);

        keys[2] = "GiftedBox";
        addresses[2] = address(0x890f8F066b6C6946D220623d6cb36b2930B80c44);

        keys[3] = "Vault";
        addresses[3] = address(0xF9aE127989ec2C8d683a0605a6dEc973f4B57d9b);

        keys[4] = "GasSponsorBook";
        addresses[4] = address(0x75260D56366fBa5933CB56efd5F671331fF9B6C5);


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
        vm.stopBroadcast();
    }
}
