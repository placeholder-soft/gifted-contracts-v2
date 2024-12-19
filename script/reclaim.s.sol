// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import "@openzeppelin/token/ERC721/IERC721.sol";
import { NFTVault } from "../src/NFTVault.sol";
import { GiftedBox } from "../src/GiftedBox.sol";
import { GiftedAccount } from "../src/GiftedAccount.sol";

contract Reclaim is Script {
  function run() public {
    reclaim(934, 0x0000000080d04343D60D06e1a36aAF46c9242805, 1457, 0xF99E6913b949D6e3da3E217D0F5E09b7f7B7d2B1);
  }

  function reclaim(uint256 giftBoxID, address artworkAddress, uint256 artworkID, address recipient) internal {
    vm.startBroadcast(getAddressFromConfig("deployer"));
    GiftedAccount tokenAccount =
      GiftedAccount(payable(GiftedBox(getAddressFromConfig("GiftedBox")).tokenAccountAddress(giftBoxID)));

    tokenAccount.executeCall(
      artworkAddress,
      0,
      abi.encodeWithSelector(IERC721.transferFrom.selector, address(tokenAccount), recipient, artworkID)
    );
    vm.stopBroadcast();
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
