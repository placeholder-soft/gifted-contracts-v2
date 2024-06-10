// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../src/GiftedBox.sol";
import {GiftedAccount, IERC6551Account} from "../src/GiftedAccount.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import "erc6551/ERC6551Registry.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "M721") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") {}

    function mint(address to, uint256 tokenId, uint256 amount) public {
        _mint(to, tokenId, amount, "");
    }

    function mintBatch(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) public {
        _mintBatch(to, tokenIds, amounts, "");
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
    MockERC721 internal mockNFT;
    MockERC1155 internal mockERC1155;
    GiftedBox internal giftedBox;
    ERC6551Registry internal registry;
    GiftedAccountGuardian internal guardian = new GiftedAccountGuardian();
    GiftedAccount internal giftedAccount;

    // region Setup
    function setUp() public {
        mockNFT = new MockERC721();
        mockERC1155 = new MockERC1155();

        GiftedAccount giftedAccountImpl = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(giftedAccountImpl));

        GiftedAccountProxy accountProxy = new GiftedAccountProxy(
            address(guardian)
        );
        giftedAccount = GiftedAccount(payable(address(accountProxy)));

        registry = new ERC6551Registry();

        address implementation = address(new GiftedBox());
        bytes memory data = abi.encodeCall(GiftedBox.initialize, address(this));
        address proxy = address(new ERC1967Proxy(implementation, data));
        giftedBox = GiftedBox(proxy);

        giftedBox.setAccountImpl(payable(address(giftedAccount)));
        giftedBox.setRegistry(address(registry));
        giftedBox.setGasSponsorBook(address(0));
        giftedBox.setAccountGuardian(address(guardian));
    }

    // endregion

    // region Gifting Actions
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

    // endregion Gifting Actions

    // region TokenBound Account

    function testTokenBoundAccountCallDirectly() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        address account = registry.account(
            address(giftedAccount),
            block.chainid,
            address(giftedBox),
            tokenId,
            0
        );

        address tokenAccount = giftedBox.tokenAccountAddress(tokenId);
        assertTrue(account != address(0));
        assertTrue(account != vm.addr(1));
        assertEq(account, tokenAccount);

        IERC6551Account accountInstance = IERC6551Account(payable(account));

        vm.prank(vm.addr(1));
        giftedBox.claimGift(tokenId, true);

        assertEq(accountInstance.owner(), vm.addr(1));

        vm.deal(account, 1 ether);

        vm.prank(vm.addr(1));
        accountInstance.executeCall(payable(vm.addr(2)), 0.5 ether, "");

        assertEq(account.balance, 0.5 ether);
        assertEq(vm.addr(2).balance, 0.5 ether);
        assertEq(accountInstance.nonce(), 1);

        vm.prank(vm.addr(1));
        giftedBox.transferFrom(vm.addr(1), vm.addr(2), tokenId);
        assertEq(accountInstance.owner(), vm.addr(2));

        vm.prank(vm.addr(1));
        vm.expectRevert();
        accountInstance.executeCall(payable(vm.addr(2)), 0.5 ether, "");

        vm.prank(vm.addr(2));
        accountInstance.executeCall(payable(vm.addr(2)), 0.5 ether, "");
        assertEq(vm.addr(2).balance, 1 ether);
        assertEq(accountInstance.nonce(), 2);
    }

    function testTokenBoundAccountERC721() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address randomAccount = vm.addr(3);

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        address tokenAccount = giftedBox.tokenAccountAddress(tokenId);

        // !important: only the token owner can transfer the token to tokenBound account
        // to prevent front running attack
        mockNFT.mint(randomAccount, 100);
        vm.expectRevert("!sender-not-authorized");
        vm.prank(randomAccount);
        mockNFT.safeTransferFrom(randomAccount, tokenAccount, 100);

        // sender is able to transfer the token to tokenBound account
        mockNFT.mint(giftSender, 101);
        vm.prank(giftSender);
        mockNFT.safeTransferFrom(giftSender, tokenAccount, 101);

        // recipient is not able to transfer the token to tokenBound account
        mockNFT.mint(giftRecipient, 102);
        vm.expectRevert("!sender-not-authorized");
        vm.prank(giftRecipient);
        mockNFT.safeTransferFrom(giftRecipient, tokenAccount, 102);
    }

    function testTokenBoundAccountERC1155() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address randomAccount = vm.addr(3);

        vm.prank(giftSender);
        giftedBox.sendGift(giftRecipient);

        address tokenAccount = giftedBox.tokenAccountAddress(tokenId);

        // !important: only the token owner can transfer the token to tokenBound account
        // to prevent front running attack
        mockERC1155.mint(randomAccount, 100, 1);
        vm.expectRevert("!sender-not-authorized");
        vm.prank(randomAccount);
        mockERC1155.safeTransferFrom(randomAccount, tokenAccount, 100, 1, "");

        // sender is able to transfer the token to tokenBound account
        mockERC1155.mint(giftSender, 101, 1);
        vm.prank(giftSender);
        mockERC1155.safeTransferFrom(giftSender, tokenAccount, 101, 1, "");

        // recipient is not able to transfer the token to tokenBound account
        mockERC1155.mint(giftRecipient, 102, 1);
        vm.expectRevert("!sender-not-authorized");
        vm.prank(giftRecipient);
        mockERC1155.safeTransferFrom(giftRecipient, tokenAccount, 102, 1, "");

        // Test cases for onERC1155BatchReceived
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 200;
        ids[1] = 201;
        amounts[0] = 1;
        amounts[1] = 2;

        // randomAccount tries to transfer batch tokens to tokenBound account
        mockERC1155.mintBatch(randomAccount, ids, amounts);
        vm.expectRevert("!sender-not-authorized");
        vm.prank(randomAccount);
        mockERC1155.safeBatchTransferFrom(
            randomAccount,
            tokenAccount,
            ids,
            amounts,
            ""
        );

        // giftSender transfers batch tokens to tokenBound account
        mockERC1155.mintBatch(giftSender, ids, amounts);
        vm.prank(giftSender);
        mockERC1155.safeBatchTransferFrom(
            giftSender,
            tokenAccount,
            ids,
            amounts,
            ""
        );

        // giftRecipient tries to transfer batch tokens to tokenBound account
        mockERC1155.mintBatch(giftRecipient, ids, amounts);
        vm.expectRevert("!sender-not-authorized");
        vm.prank(giftRecipient);
        mockERC1155.safeBatchTransferFrom(
            giftRecipient,
            tokenAccount,
            ids,
            amounts,
            ""
        );
    }
    // endregion TokenBound Account
}
