// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { NFTVault } from "../src/NFTVault.sol";
import { GiftedBox } from "../src/GiftedBox.sol";
import { GiftedAccount } from "../src/GiftedAccount.sol";

contract Burn is Script {
  IERC721 public nftContract;

  function run() public {
    burnNFTs(
      [
        106,
        91,
        90,
        89,
        88,
        87,
        86,
        85,
        84,
        83,
        82,
        80,
        79,
        78,
        74,
        73,
        72,
        71,
        69,
        68,
        67,
        66,
        65,
        64,
        63,
        62,
        61,
        60,
        59,
        58,
        57,
        55,
        54,
        53,
        52,
        51,
        43,
        40,
        38,
        36
      ]
    );
  }

  function burnNFTs(uint8[40] memory tokenIds) internal {
    vm.startBroadcast(getAddressFromConfig("manager"));
    nftContract = IERC721(0x2D37C6bfcb5CDD2cDb5c48C107B56a85B77d62e8);
    address owner = getAddressFromConfig("manager");

    for (uint256 i = 0; i < tokenIds.length; i++) {
      nftContract.transferFrom(address(owner), address(0xdead), uint256(tokenIds[i]));
    }
    vm.stopBroadcast();
  }

  function burnNFT(uint256 giftedBoxTokenId, uint256 tokenId) internal {
    vm.startBroadcast(getAddressFromConfig("deployer"));
    nftContract = IERC721(0x2D37C6bfcb5CDD2cDb5c48C107B56a85B77d62e8);

    GiftedBox giftedBox = GiftedBox(getAddressFromConfig("GiftedBox"));

    GiftedAccount giftedAccount = GiftedAccount(payable(giftedBox.tokenAccountAddress(giftedBoxTokenId)));

    bytes memory data =
      abi.encodeWithSelector(IERC721.transferFrom.selector, address(giftedAccount), address(0xdead), tokenId);

    try giftedAccount.executeCall(address(nftContract), 0, data) {
      console.log(
        "Burned NFT with token ID %s, giftedBoxTokenId: %s, from account %s",
        tokenId,
        giftedBoxTokenId,
        address(giftedAccount)
      );
    } catch {
      console.log(
        "Failed to burn NFT with token ID %s, giftedBoxTokenId: %s, from account %s",
        tokenId,
        giftedBoxTokenId,
        address(giftedAccount)
      );
    }

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
