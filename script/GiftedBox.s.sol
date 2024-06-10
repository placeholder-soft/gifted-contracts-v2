// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {GiftedBox} from "../src/GiftedBox.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GiftedBoxScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        address implementation = address(new GiftedBox());
        bytes memory data = abi.encodeCall(GiftedBox.initialize, address(this));
        address proxy = address(new ERC1967Proxy(implementation, data));
        GiftedBox giftedBox = GiftedBox(proxy);
        vm.stopBroadcast();
    }
}
