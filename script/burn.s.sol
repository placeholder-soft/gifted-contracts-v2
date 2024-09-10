// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {NFTVault} from "../src/NFTVault.sol";
import {GiftedBox} from "../src/GiftedBox.sol";
import {GiftedAccount} from "../src/GiftedAccount.sol";

contract Burn is Script {
    IERC721 public nftContract;

    function run() public {
        burnNFT(148, 13);
        burnNFT(149, 14);
        burnNFT(165, 16);
        // burnNFT(542, 47);
        burnNFT(543, 48);
        burnNFT(544, 49);
        burnNFT(545, 50);
        burnNFT(548, 77);
        burnNFT(551, 96);
        burnNFT(563, 99);
        burnNFT(565, 101);
        burnNFT(568, 102);
        burnNFT(570, 104);
        burnNFT(572, 105);
        burnNFT(575, 107);
        burnNFT(580, 109);
        burnNFT(582, 110);
        // burnNFT(587, 112);
        burnNFT(590, 113);
        burnNFT(594, 115);
        burnNFT(596, 116);
        burnNFT(598, 117);
        burnNFT(601, 118);
        // burnNFT(604, 119);
        burnNFT(609, 121);
        burnNFT(612, 122);
        burnNFT(614, 123);
        burnNFT(651, 127);
        burnNFT(660, 129);
        burnNFT(661, 130);
        burnNFT(662, 131);
        burnNFT(663, 132);
        burnNFT(664, 133);
        burnNFT(665, 134);
        burnNFT(668, 137);
        burnNFT(669, 138);
        // burnNFT(670, 139);
        burnNFT(671, 140);
        burnNFT(673, 98);
        // burnNFT(675, 142);
        burnNFT(704, 157);
    }

    function burnNFT(uint256 giftedBoxTokenId, uint256 tokenId) internal {
        vm.startBroadcast(getAddressFromConfig("deployer"));
        nftContract = IERC721(0x2D37C6bfcb5CDD2cDb5c48C107B56a85B77d62e8);

        GiftedBox giftedBox = GiftedBox(getAddressFromConfig("GiftedBox"));

        GiftedAccount giftedAccount = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(giftedBoxTokenId))
        );

        bytes memory data = abi.encodeWithSelector(
            IERC721.transferFrom.selector,
            address(giftedAccount),
            address(0xdead),
            tokenId
        );

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

    function getAddressFromConfig(
        string memory key
    ) internal view returns (address) {
        string memory env = vm.envString("DEPLOY_ENV");
        require(bytes(env).length > 0, "DEPLOY_ENV must be set");
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/config/",
            env,
            "_addresses.json"
        );
        string memory json = vm.readFile(path);
        bytes memory addressBytes = vm.parseJson(
            json,
            string.concat(".", vm.toString(block.chainid), ".", key)
        );
        return abi.decode(addressBytes, (address));
    }
}
