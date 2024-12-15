// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/Vm.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/GiftedBox.sol";
import {GiftedAccount, IERC6551Account} from "../src/GiftedAccount.sol";
import "../src/GiftedAccountGuardian.sol";
import "../src/GiftedAccountProxy.sol";
import "erc6551/ERC6551Registry.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/interfaces/ISwapRouter.sol";
import "../src/interfaces/IQuoter.sol";
import "../src/interfaces/IUnifiedStore.sol";
import "../src/UnifiedStore.sol";
import "../src/Vault.sol";
import "../src/GasSponsorBook.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "M721") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract MockSwapRouter is ISwapRouter {
    uint256 private constant ETH_PRICE = 2000; // 1 ETH = 2000 USDC

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut) {
        // Get USDC decimals dynamically
        uint8 tokenInDecimals = IERC20Metadata(params.tokenIn).decimals();
        // Mock the swap by converting USDC to ETH at a fixed rate
        amountOut =
            (params.amountIn * 1e18) /
            (ETH_PRICE * (10 ** uint256(tokenInDecimals)));

        // Transfer USDC from sender to this contract
        IERC20(params.tokenIn).transferFrom(
            msg.sender,
            address(this),
            params.amountIn
        );

        // Transfer ETH to recipient
        (bool success, ) = payable(params.recipient).call{value: amountOut}("");
        require(success, "ETH transfer failed");
    }

    // Function to receive ETH
    receive() external payable {}
}

contract MockQuoter is IQuoter {
    uint256 public constant ETH_PRICE = 2000; // 1 ETH = 2000 USDC

    function quoteExactInputSingle(
        address tokenIn,
        address,
        uint24,
        uint256 amountIn,
        uint160
    ) external view returns (uint256 amountOut) {
        // Get USDC decimals dynamically
        uint8 tokenInDecimals = IERC20Metadata(tokenIn).decimals();

        // Convert to ETH (18 decimals)
        // amountOut = amountIn * (1e18 / (ETH_PRICE * 10^tokenInDecimals))
        amountOut =
            (amountIn * 1e18) /
            (ETH_PRICE * (10 ** uint256(tokenInDecimals)));
        return amountOut;
    }
}

contract GiftedAccountUSDCToETHTest is Test {
    MockERC721 internal mockNFT;
    MockUSDC internal mockUSDC;
    MockQuoter internal mockQuoter;
    MockSwapRouter internal mockRouter;
    GiftedBox internal giftedBox;
    ERC6551Registry internal registry;
    GiftedAccountGuardian internal guardian;
    GiftedAccount internal giftedAccount;
    Vault public vault;
    GasSponsorBook public sponsorBook;
    address gasRelayer = vm.addr(32000);
    address internal owner;
    address internal recipient;
    UnifiedStore internal store;
    uint256 internal constant NFT_TOKEN_ID = 1;
    uint256 internal constant GIFTED_BOX_TOKEN_ID = 0;

    function setUp() public {
        owner = vm.addr(1);
        recipient = vm.addr(2);
        vm.deal(owner, 100 ether);
        vm.deal(address(this), 100 ether);

        // Deploy mock contracts
        mockNFT = new MockERC721();
        mockUSDC = new MockUSDC();
        mockQuoter = new MockQuoter();
        mockRouter = new MockSwapRouter();
        store = new UnifiedStore();

        // Deploy and setup guardian
        guardian = new GiftedAccountGuardian();
        GiftedAccount giftedAccountImpl = new GiftedAccount();
        guardian.setGiftedAccountImplementation(address(giftedAccountImpl));
        guardian.setUnifiedStore(address(store));

        // Deploy account proxy
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

        // Setup initial state
        mockNFT.mint(owner, NFT_TOKEN_ID);

        store.setAddress("UNISWAP_ROUTER", address(mockRouter));
        store.setAddress("TOKEN_USDC", address(mockUSDC));
        store.setAddress("UNISWAP_QUOTER", address(mockQuoter));

        // Fund the router with ETH for swaps
        vm.deal(address(mockRouter), 1000 ether);

        vm.prank(owner);
        // Create GiftedBox and account
        giftedBox.sendGift{value: 0}(owner, recipient, address(0), 0); // Mint GiftedBox NFT with tokenId 1

        vm.prank(recipient);
        giftedBox.claimGift(GIFTED_BOX_TOKEN_ID, GiftingRole.RECIPIENT);
    }

    function test_QuoteUSDCToETHSingle() public {
        GiftedAccount account = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(GIFTED_BOX_TOKEN_ID))
        );

        // Set initial USDC balance to 1000 USDC
        uint256 initialBalance = 1000 * 10 ** 6;
        mockUSDC.mint(address(account), initialBalance);

        // Test 50% conversion (50000 = 50%)
        (uint256 expectedOutput, uint256 amountIn,) = account.quoteUSDCToETH(
            50000
        );

        // Expected calculations:
        // 50% of 1000 USDC = 500 USDC
        // 500 USDC = 0.25 ETH (since 1 ETH = 2000 USDC)
        // 0.25 ETH = 0.25 * 10^18 = 250000000000000000 wei
        assertEq(amountIn, 500 * 10 ** 6, "Input should be 500 USDC");
        assertEq(expectedOutput, 25 * 10 ** 16, "Output should be 0.25 ETH");
    }

    function test_QuoteUSDCToETH_ZeroPercent() public {
        GiftedAccount account = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(GIFTED_BOX_TOKEN_ID))
        );

        // Set initial USDC balance to 1000 USDC
        mockUSDC.mint(address(account), 1000 * 10 ** 6);

        // Test 0% conversion
        (uint256 expectedOutput, uint256 amountIn,) = account.quoteUSDCToETH(0);

        assertEq(amountIn, 0, "Input should be 0 USDC");
        assertEq(expectedOutput, 0, "Output should be 0 ETH");
    }

    function test_QuoteUSDCToETH_FullConversion() public {
        GiftedAccount account = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(GIFTED_BOX_TOKEN_ID))
        );

        // Set initial USDC balance to 1000 USDC
        uint256 initialBalance = 1000 * 10 ** 6;
        mockUSDC.mint(address(account), initialBalance);

        // Test 100% conversion (100000 = 100%)
        (uint256 expectedOutput, uint256 amountIn,) = account.quoteUSDCToETH(
            100000
        );

        // Expected calculations:
        // 100% of 1000 USDC = 1000 USDC
        // 1000 USDC = 0.5 ETH (since 1 ETH = 2000 USDC)
        // 0.5 ETH = 0.5 * 10^18 = 500000000000000000 wei
        assertEq(amountIn, 1000 * 10 ** 6, "Input should be 1000 USDC");
        assertEq(expectedOutput, 50 * 10 ** 16, "Output should be 0.5 ETH");
    }

    function test_ConvertUSDCToETHAndSendSingle() public {
        GiftedAccount account = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(GIFTED_BOX_TOKEN_ID))
        );
        // Set initial USDC balance to 1000 USDC
        uint256 initialBalance = 1000 * 10 ** 6;
        mockUSDC.mint(address(account), initialBalance);

        vm.startPrank(recipient);

        // Record initial balances
        uint256 initialUSDCBalance = mockUSDC.balanceOf(address(account));
        uint256 initialRecipientUSDCBalance = mockUSDC.balanceOf(recipient);
        uint256 initialRecipientETHBalance = recipient.balance;

        // Convert 50% of USDC to ETH and send to recipient
        account.convertUSDCToETHAndSend(50000, recipient);

        // Verify final balances
        assertEq(
            mockUSDC.balanceOf(address(account)),
            0,
            "!account-should-have-no-usdc"
        );
        assertEq(
            mockUSDC.balanceOf(recipient),
            initialRecipientUSDCBalance + initialUSDCBalance / 2,
            "!incorrect-recipient-usdc"
        );
        assertEq(
            recipient.balance,
            initialRecipientETHBalance + 0.25 ether,
            "!incorrect-recipient-eth"
        );

        vm.stopPrank();
    }

    function testRevert_ConvertUSDCToETHAndSend_NotOwner() public {
        GiftedAccount account = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(GIFTED_BOX_TOKEN_ID))
        );
        vm.prank(makeAddr("notOwner"));
        vm.expectRevert("!not-authorized");
        account.convertUSDCToETHAndSend(50000, recipient);
    }

    function testRevert_ConvertUSDCToETHAndSend_InvalidPercentage() public {
        GiftedAccount account = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(GIFTED_BOX_TOKEN_ID))
        );
        vm.expectRevert("!invalid-percentage");
        vm.prank(recipient);
        account.convertUSDCToETHAndSend(100001, recipient);
    }

    function testRevert_ConvertUSDCToETHAndSend_ZeroRecipient() public {
        GiftedAccount account = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(GIFTED_BOX_TOKEN_ID))
        );
        vm.prank(recipient);
        vm.expectRevert("!invalid-recipient");
        account.convertUSDCToETHAndSend(50000, address(0));
    }

    function test_ConvertUSDCToETHAndSend_ZeroPercent() public {
        GiftedAccount account = GiftedAccount(
            payable(giftedBox.tokenAccountAddress(GIFTED_BOX_TOKEN_ID))
        );

        uint256 initialUSDCBalance = mockUSDC.balanceOf(address(account));

        vm.prank(recipient);
        account.convertUSDCToETHAndSend(0, recipient);

        // All USDC should be transferred to recipient, no conversion
        assertEq(
            mockUSDC.balanceOf(recipient),
            initialUSDCBalance,
            "!incorrect-usdc-transfer"
        );
        assertEq(recipient.balance, 0, "!should-have-no-eth");

        vm.stopPrank();
    }

    receive() external payable {} // Allow contract to receive ETH
}
