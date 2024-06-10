// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../src/GiftedBox.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "M721") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

interface TestEvents {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
}

contract GiftedBoxTest is Test, TestEvents {
    MockERC721 mockNFT;
    GiftedBox giftedBox;

    function setUp() public {
        mockNFT = new MockERC721();
        address implementation = address(new GiftedBox());
        bytes memory data = abi.encodeCall(GiftedBox.initialize, address(this));
        address proxy = address(new ERC1967Proxy(implementation, data));
        giftedBox = GiftedBox(proxy);
    }

    function testSendGift() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        assertEq(address(giftedBox), IERC721(giftedBox).ownerOf(tokenId));

        (address sender, address recipient) = giftedBox.giftingRecords(tokenId);
        assertEq(giftSender, sender);
        assertEq(giftRecipient, recipient);
    }

    function testClaimGiftByRecipient() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        vm.prank(giftRecipient);
        giftedBox.claimGift(tokenId, false);

        assertEq(giftRecipient, IERC721(giftedBox).ownerOf(tokenId));
        (address sender, address recipient) = giftedBox.giftingRecords(tokenId);
        assertEq(sender, address(0));
        assertEq(recipient, address(0));
    }

    function testClaimGiftBySender() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        vm.prank(giftSender);
        giftedBox.claimGift(tokenId, true);

        assertEq(giftSender, IERC721(giftedBox).ownerOf(tokenId));
        (address sender, address recipient) = giftedBox.giftingRecords(tokenId);
        assertEq(sender, address(0));
        assertEq(recipient, address(0));
    }

    function testClaimGiftByAdmin() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        giftedBox.claimGiftByAdmin(tokenId, giftSender, true);

        assertEq(giftSender, IERC721(giftedBox).ownerOf(tokenId));
        {
            (address sender, address recipient) = giftedBox.giftingRecords(
                tokenId
            );
            assertEq(sender, address(0));
            assertEq(recipient, address(0));
        }

        tokenId++;

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        vm.expectRevert("!not-recipient");
        giftedBox.claimGiftByAdmin(tokenId, giftSender, false);

        giftedBox.claimGiftByAdmin(tokenId, giftRecipient, false);
        assertEq(giftRecipient, IERC721(giftedBox).ownerOf(tokenId));
        {
            (address sender, address recipient) = giftedBox.giftingRecords(
                tokenId
            );
            assertEq(sender, address(0));
            assertEq(recipient, address(0));
        }
    }

    function testResendGift() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        vm.prank(giftSender);
        giftedBox.claimGift(tokenId, true);

        vm.prank(giftSender);
        giftedBox.resendGift(tokenId, giftRecipient);

        assertEq(address(giftedBox), IERC721(giftedBox).ownerOf(tokenId));
        {
            (address sender, address recipient) = giftedBox.giftingRecords(
                tokenId
            );
            assertEq(sender, giftSender);
            assertEq(recipient, giftRecipient);
        }

        vm.prank(giftRecipient);
        giftedBox.claimGift(tokenId, false);
        {
            (address sender, address recipient) = giftedBox.giftingRecords(
                tokenId
            );
            assertEq(address(0), sender);
            assertEq(address(0), recipient);
        }
    }
}
