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
import "../src/Vault.sol";
import "../src/GasSponsorBook.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "M20") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
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
    MockERC721 internal mockERC721;
    MockERC1155 internal mockERC1155;
    GiftedBox internal giftedBox;
    ERC6551Registry internal registry;
    GiftedAccountGuardian internal guardian = new GiftedAccountGuardian();
    GiftedAccount internal giftedAccount;
    Vault public vault;
    GasSponsorBook public sponsorBook;
    address gasRelayer = vm.addr(32000);
    MockERC20 internal mockERC20;

    // region Setup
    function setUp() public {
        mockERC721 = new MockERC721();
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
        giftedBox.setAccountGuardian(address(guardian));
        giftedBox.grantRole(giftedBox.CLAIMER_ROLE(), gasRelayer);

        vault = new Vault();
        vault.initialize(address(this));
        sponsorBook = new GasSponsorBook();
        vault.grantRole(vault.CONTRACT_ROLE(), address(sponsorBook));
        vault.grantRole(vault.CONTRACT_ROLE(), address(giftedBox));

        sponsorBook.setVault(vault);
        giftedBox.setGasSponsorBook(address(sponsorBook));
        sponsorBook.grantRole(sponsorBook.SPONSOR_ROLE(), address(giftedBox));
        sponsorBook.grantRole(sponsorBook.CONSUMER_ROLE(), gasRelayer);

        giftedBox.setVault(address(vault));

        mockERC20 = new MockERC20();

        vm.deal(gasRelayer, 100 ether);
    }

    // endregion

    // region Gifting Actions
    function testSendGift() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address giftOperator = vm.addr(3);

        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);

        assertEq(address(giftedBox), IERC721(giftedBox).ownerOf(tokenId));

        (address sender, address recipient, address operator) = giftedBox
            .giftingRecords(tokenId);
        assertEq(giftSender, sender);
        assertEq(giftRecipient, recipient);
        assertEq(giftOperator, operator);
    }

    function testClaimGiftByRecipient() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address giftOperator = vm.addr(3);

        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);

        vm.prank(giftRecipient);
        giftedBox.claimGift(tokenId, GiftingRole.RECIPIENT);

        assertEq(giftRecipient, IERC721(giftedBox).ownerOf(tokenId));
        (address sender, address recipient, address operator) = giftedBox
            .giftingRecords(tokenId);
        assertEq(sender, address(0));
        assertEq(recipient, address(0));
        assertEq(operator, address(0));
    }

    function testClaimGiftBySender() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address giftOperator = vm.addr(3);

        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);

        vm.prank(giftSender);
        giftedBox.claimGift(tokenId, GiftingRole.SENDER);

        assertEq(giftSender, IERC721(giftedBox).ownerOf(tokenId));
        (address sender, address recipient, address operator) = giftedBox
            .giftingRecords(tokenId);
        assertEq(sender, address(0));
        assertEq(recipient, address(0));
        assertEq(operator, address(0));
    }

    function testclaimGiftByClaimer() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address giftOperator = vm.addr(3);

        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);
        giftedBox.claimGiftByClaimer(tokenId, GiftingRole.SENDER);

        assertEq(giftSender, IERC721(giftedBox).ownerOf(tokenId));
        {
            (address sender, address recipient, address operator) = giftedBox
                .giftingRecords(tokenId);
            assertEq(sender, address(0));
            assertEq(recipient, address(0));
            assertEq(operator, address(0));
        }

        tokenId++;

        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);

        giftedBox.claimGiftByClaimer(tokenId, GiftingRole.RECIPIENT);
        assertEq(giftRecipient, IERC721(giftedBox).ownerOf(tokenId));
        {
            (address sender, address recipient, address operator) = giftedBox
                .giftingRecords(tokenId);
            assertEq(sender, address(0));
            assertEq(recipient, address(0));
            assertEq(operator, address(0));
        }

        tokenId++;

        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);

        vm.expectRevert("!invalid-role");
        giftedBox.claimGiftByClaimer(tokenId, GiftingRole.OPERATOR);
    }

    // endregion Gifting Actions

    // region TokenBound Account

    function testTokenBoundAccountCallDirectly() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);

        vm.prank(giftSender);
        giftedBox.sendGift(giftSender, giftRecipient);

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
        giftedBox.claimGift(tokenId, GiftingRole.SENDER);

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
        giftedBox.sendGift(giftSender, giftRecipient);

        address tokenAccount = giftedBox.tokenAccountAddress(tokenId);

        // !important: only the token owner can transfer the token to tokenBound account
        // to prevent front running attack
        mockERC721.mint(randomAccount, 100);
        vm.expectRevert("!sender-not-authorized");
        vm.prank(randomAccount);
        mockERC721.safeTransferFrom(randomAccount, tokenAccount, 100);

        // sender is able to transfer the token to tokenBound account
        mockERC721.mint(giftSender, 101);
        vm.prank(giftSender);
        mockERC721.safeTransferFrom(giftSender, tokenAccount, 101);

        // recipient is not able to transfer the token to tokenBound account
        mockERC721.mint(giftRecipient, 102);
        vm.expectRevert("!sender-not-authorized");
        vm.prank(giftRecipient);
        mockERC721.safeTransferFrom(giftRecipient, tokenAccount, 102);
    }

    function testTokenBoundAccountERC1155() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address randomAccount = vm.addr(3);

        vm.prank(giftSender);
        giftedBox.sendGift(giftSender, giftRecipient);

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

    // region Forward Methods
    function testTransferERC721() public {
        uint256 giftedBoxTokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address tokenRecipient = vm.addr(3);
        address giftOperator = vm.addr(4);
        uint256 tokenId = 100;

        // Send gift
        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);

        // Mint ERC721 token to giftSender
        mockERC721.mint(giftOperator, tokenId);

        // Transfer ERC721 token to token-bound account
        GiftedAccount tokenAccount = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(giftedBoxTokenId))
        );
        vm.prank(giftOperator);
        mockERC721.safeTransferFrom(
            giftOperator,
            address(tokenAccount),
            tokenId
        );

        // Claim gift to recipient
        vm.prank(giftRecipient);
        giftedBox.claimGift(giftedBoxTokenId, GiftingRole.RECIPIENT);

        // Generate permit message
        string memory permitMessage = giftedBox.transferERC721PermitMessage(
            giftedBoxTokenId,
            address(mockERC721),
            tokenId,
            tokenRecipient,
            block.timestamp + 1 days
        );

        // Sign permit message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            2, // giftRecipient's private key
            tokenAccount.hashPersonalSignedMessage(bytes(permitMessage))
        );

        // Transfer ERC721 token using permit
        vm.prank(giftSender);
        giftedBox.transferERC721(
            giftedBoxTokenId,
            address(mockERC721),
            tokenId,
            tokenRecipient,
            block.timestamp + 1 days,
            v,
            r,
            s
        );

        // Verify token ownership
        assertEq(mockERC721.ownerOf(tokenId), tokenRecipient);
    }

    function testTransferERC1155() public {
        uint256 giftedBoxTokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address tokenRecipient = vm.addr(3);
        address giftOperator = vm.addr(4);
        uint256 tokenId = 100;
        uint256 amount = 10;

        // Send gift
        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);

        // Mint ERC1155 token to giftSender
        mockERC1155.mint(giftOperator, tokenId, amount);

        // Transfer ERC1155 token to token-bound account
        GiftedAccount tokenAccount = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(giftedBoxTokenId))
        );
        vm.prank(giftOperator);
        mockERC1155.safeTransferFrom(
            giftOperator,
            address(tokenAccount),
            tokenId,
            amount,
            ""
        );

        // Claim gift to recipient
        vm.prank(giftRecipient);
        giftedBox.claimGift(giftedBoxTokenId, GiftingRole.RECIPIENT);

        // Generate permit message
        string memory permitMessage = giftedBox.transferERC1155PermitMessage(
            giftedBoxTokenId,
            address(mockERC1155),
            tokenId,
            amount,
            tokenRecipient,
            block.timestamp + 1 days
        );

        // Sign permit message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            2, // giftRecipient's private key
            tokenAccount.hashPersonalSignedMessage(bytes(permitMessage))
        );

        // Transfer ERC1155 token using permit
        vm.prank(giftSender);
        giftedBox.transferERC1155(
            giftedBoxTokenId,
            address(mockERC1155),
            tokenId,
            amount,
            tokenRecipient,
            block.timestamp + 1 days,
            v,
            r,
            s
        );

        // Verify token ownership
        assertEq(mockERC1155.balanceOf(tokenRecipient, tokenId), amount);
    }

    // region Gas Sponsor
    function testGasSponsorBookWithConsumer() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address giftOperator = vm.addr(3);
        uint256 feePerTicket = giftedBox.feePerSponsorTicket();
        vm.deal(giftOperator, feePerTicket * 2);

        vm.prank(giftOperator);
        giftedBox.sendGift{value: feePerTicket * 2}(giftSender, giftRecipient);

        uint256 beforeBalance = gasRelayer.balance;
        vm.prank(gasRelayer);
        giftedBox.claimGiftByClaimerConsumeSponsorTicket(
            tokenId,
            GiftingRole.SENDER
        );
        vm.assertEq(gasRelayer.balance, beforeBalance + feePerTicket);
    }

    function testTransferERC721Sponsor() public {
        uint256 giftedBoxTokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address tokenRecipient = vm.addr(3);
        address giftOperator = vm.addr(4);
        uint256 tokenId = 100;
        uint256 feePerTicket = giftedBox.feePerSponsorTicket();
        vm.deal(giftOperator, feePerTicket);

        // Send gift
        vm.prank(giftOperator);
        giftedBox.sendGift{value: feePerTicket}(giftSender, giftRecipient);

        // Mint ERC721 token to giftSender
        mockERC721.mint(giftOperator, tokenId);

        // Transfer ERC721 token to token-bound account
        GiftedAccount tokenAccount = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(giftedBoxTokenId))
        );
        vm.prank(giftOperator);
        mockERC721.safeTransferFrom(
            giftOperator,
            address(tokenAccount),
            tokenId
        );

        // Claim gift to recipient
        vm.prank(giftRecipient);
        giftedBox.claimGift(giftedBoxTokenId, GiftingRole.RECIPIENT);

        // Generate permit message
        string memory permitMessage = giftedBox.transferERC721PermitMessage(
            giftedBoxTokenId,
            address(mockERC721),
            tokenId,
            tokenRecipient,
            block.timestamp + 1 days
        );

        // Sign permit message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            2, // giftRecipient's private key
            tokenAccount.hashPersonalSignedMessage(bytes(permitMessage))
        );

        // Transfer ERC721 token using sponsor
        vm.prank(gasRelayer);
        giftedBox.transferERC721Sponsor(
            giftedBoxTokenId,
            address(mockERC721),
            tokenId,
            tokenRecipient,
            block.timestamp + 1 days,
            v,
            r,
            s
        );

        // Verify token ownership
        assertEq(mockERC721.ownerOf(tokenId), tokenRecipient);
    }

    function testTransferERC1155Sponsor() public {
        uint256 giftedBoxTokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address tokenRecipient = vm.addr(3);
        address giftOperator = vm.addr(4);
        uint256 tokenId = 100;
        uint256 amount = 10;
        uint256 feePerTicket = giftedBox.feePerSponsorTicket();
        vm.deal(giftOperator, feePerTicket);

        // Send gift
        vm.prank(giftOperator);
        giftedBox.sendGift{value: feePerTicket}(giftSender, giftRecipient);

        // Mint ERC1155 token to giftSender
        mockERC1155.mint(giftOperator, tokenId, amount);

        // Transfer ERC1155 token to token-bound account
        GiftedAccount tokenAccount = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(giftedBoxTokenId))
        );
        vm.prank(giftOperator);
        mockERC1155.safeTransferFrom(
            giftOperator,
            address(tokenAccount),
            tokenId,
            amount,
            ""
        );

        // Claim gift to recipient
        vm.prank(giftRecipient);
        giftedBox.claimGift(giftedBoxTokenId, GiftingRole.RECIPIENT);

        // Generate permit message
        string memory permitMessage = giftedBox.transferERC1155PermitMessage(
            giftedBoxTokenId,
            address(mockERC1155),
            tokenId,
            amount,
            tokenRecipient,
            block.timestamp + 1 days
        );

        // Sign permit message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            2, // giftRecipient's private key
            tokenAccount.hashPersonalSignedMessage(bytes(permitMessage))
        );

        // Transfer ERC1155 token using sponsor
        vm.prank(gasRelayer);
        giftedBox.transferERC1155Sponsor(
            giftedBoxTokenId,
            address(mockERC1155),
            tokenId,
            amount,
            tokenRecipient,
            block.timestamp + 1 days,
            v,
            r,
            s
        );

        // Verify token ownership
        assertEq(mockERC1155.balanceOf(tokenRecipient, tokenId), amount);
    }

    // endregion Gas Sponsor

    // Add these new test functions
    function testSendGiftWithMintingFee() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address giftOperator = vm.addr(3);
        uint256 mintingFee = 0.01 ether;

        vm.deal(giftOperator, mintingFee);

        uint256 vaultBalanceBefore = address(vault).balance;

        vm.prank(giftOperator);
        giftedBox.sendGift{value: mintingFee}(giftSender, giftRecipient, giftOperator, mintingFee);

        assertEq(address(giftedBox), IERC721(giftedBox).ownerOf(tokenId), "!owner");
        assertEq(address(vault).balance, vaultBalanceBefore + mintingFee, "!vault-balance");

        (address sender, address recipient, address operator) = giftedBox.giftingRecords(tokenId);
        assertEq(giftSender, sender, "!sender");
        assertEq(giftRecipient, recipient, "!recipient");
        assertEq(giftOperator, operator, "!operator");
    }

    function testSendGiftWithSponsorTicket() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address giftOperator = vm.addr(3);
        uint256 sponsorFee = giftedBox.feePerSponsorTicket();

        vm.deal(giftOperator, sponsorFee);

        vm.prank(giftOperator);
        giftedBox.sendGift{value: sponsorFee}(giftSender, giftRecipient);

        assertEq(address(giftedBox), IERC721(giftedBox).ownerOf(tokenId), "!owner");
        assertEq(giftedBox.sponsorTickets(tokenId), 1, "!sponsor-tickets");

        (address sender, address recipient, address operator) = giftedBox.giftingRecords(tokenId);
        assertEq(giftSender, sender, "!sender");
        assertEq(giftRecipient, recipient, "!recipient");
        assertEq(giftOperator, operator, "!operator");
    }

    function testSendGiftWithMintingFeeAndSponsorTicket() public {
        uint256 tokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address giftOperator = vm.addr(3);
        uint256 mintingFee = 0.01 ether;
        uint256 sponsorFee = giftedBox.feePerSponsorTicket();
        uint256 totalFee = mintingFee + sponsorFee;

        vm.deal(giftOperator, totalFee);

        uint256 vaultBalanceBefore = address(vault).balance;

        vm.prank(giftOperator);
        giftedBox.sendGift{value: totalFee}(giftSender, giftRecipient, giftOperator, mintingFee);

        assertEq(address(giftedBox), IERC721(giftedBox).ownerOf(tokenId), "!owner");
        assertEq(address(vault).balance, vaultBalanceBefore + mintingFee + sponsorFee, "!vault-balance");
        assertEq(giftedBox.sponsorTickets(tokenId), 1, "!sponsor-tickets");

        (address sender, address recipient, address operator) = giftedBox.giftingRecords(tokenId);
        assertEq(giftSender, sender, "!sender");
        assertEq(giftRecipient, recipient, "!recipient");
        assertEq(giftOperator, operator, "!operator");
    }

    function testTransferERC20() public {
        uint256 giftedBoxTokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address tokenRecipient = vm.addr(3);
        address giftOperator = vm.addr(4);
        uint256 amount = 100;

        // Send gift
        vm.prank(giftOperator);
        giftedBox.sendGift(giftSender, giftRecipient);

        // Mint ERC20 tokens to giftOperator
        mockERC20.mint(giftOperator, amount);

        // Transfer ERC20 tokens to token-bound account
        GiftedAccount tokenAccount = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(giftedBoxTokenId))
        );
        vm.prank(giftOperator);
        mockERC20.transfer(address(tokenAccount), amount);

        // Claim gift to recipient
        vm.prank(giftRecipient);
        giftedBox.claimGift(giftedBoxTokenId, GiftingRole.RECIPIENT);

        // Generate permit message
        string memory permitMessage = giftedBox.transferERC20PermitMessage(
            giftedBoxTokenId,
            address(mockERC20),
            amount,
            tokenRecipient,
            block.timestamp + 1 days
        );

        // Sign permit message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            2, // giftRecipient's private key
            tokenAccount.hashPersonalSignedMessage(bytes(permitMessage))
        );

        // Transfer ERC20 tokens using permit
        vm.prank(giftSender);
        giftedBox.transferERC20(
            giftedBoxTokenId,
            address(mockERC20),
            amount,
            tokenRecipient,
            block.timestamp + 1 days,
            v,
            r,
            s
        );

        // Verify token ownership
        assertEq(mockERC20.balanceOf(tokenRecipient), amount);
    }

    function testTransferERC20Sponsor() public {
        uint256 giftedBoxTokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address tokenRecipient = vm.addr(3);
        address giftOperator = vm.addr(4);
        uint256 amount = 100;
        uint256 feePerTicket = giftedBox.feePerSponsorTicket();
        vm.deal(giftOperator, feePerTicket);

        // Send gift with sponsor ticket
        vm.prank(giftOperator);
        giftedBox.sendGift{value: feePerTicket}(giftSender, giftRecipient);

        // Mint ERC20 tokens to giftOperator
        mockERC20.mint(giftOperator, amount);

        // Transfer ERC20 tokens to token-bound account
        GiftedAccount tokenAccount = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(giftedBoxTokenId))
        );
        vm.prank(giftOperator);
        mockERC20.transfer(address(tokenAccount), amount);

        // Claim gift to recipient
        vm.prank(giftRecipient);
        giftedBox.claimGift(giftedBoxTokenId, GiftingRole.RECIPIENT);

        // Generate permit message
        string memory permitMessage = giftedBox.transferERC20PermitMessage(
            giftedBoxTokenId,
            address(mockERC20),
            amount,
            tokenRecipient,
            block.timestamp + 1 days
        );

        // Sign permit message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            2, // giftRecipient's private key
            tokenAccount.hashPersonalSignedMessage(bytes(permitMessage))
        );

        // Transfer ERC20 tokens using sponsor
        vm.prank(gasRelayer);
        giftedBox.transferERC20Sponsor(
            giftedBoxTokenId,
            address(mockERC20),
            amount,
            tokenRecipient,
            block.timestamp + 1 days,
            v,
            r,
            s
        );

        // Verify token ownership
        assertEq(mockERC20.balanceOf(tokenRecipient), amount);
    }

    function testTransferERC20PermitMessage() public {
        uint256 giftedBoxTokenId = 0;
        address giftSender = vm.addr(1);
        address giftRecipient = vm.addr(2);
        address tokenRecipient = vm.addr(3);
        uint256 amount = 100;
        uint256 deadline = block.timestamp + 1 days;

        // Send gift
        vm.prank(giftSender);
        giftedBox.sendGift(giftSender, giftRecipient);

        // Generate permit message
        string memory permitMessage = giftedBox.transferERC20PermitMessage(
            giftedBoxTokenId,
            address(mockERC20),
            amount,
            tokenRecipient,
            deadline
        );

        // Verify permit message content
        assertEq(
            permitMessage,
            string(
                abi.encodePacked(
                    "I authorize the transfer of ERC20 tokens",
                    "\n Token Contract: ",
                    Strings.toHexString(uint256(uint160(address(mockERC20))), 20),
                    "\n Amount: ",
                    Strings.toString(amount),
                    "\n To: ",
                    Strings.toHexString(uint256(uint160(tokenRecipient)), 20),
                    "\n Deadline: ",
                    Strings.toString(deadline),
                    "\n Nonce: ",
                    Strings.toString(0),
                    "\n Chain ID: ",
                    Strings.toString(block.chainid),
                    "\n BY: ",
                    "GiftedAccount",
                    "\n Version: ",
                    "0.0.2"
                )
            )
        );
    }
}
