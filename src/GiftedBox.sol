// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;
import "@openzeppelin/utils/Address.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import {GiftedAccount} from "./GiftedAccount.sol";
import "./GiftedAccountGuardian.sol";
import "./interfaces/IGasSponsorBook.sol";
import "./interfaces/IGiftedBox.sol";
import "./interfaces/IGiftedAccount.sol";
import "erc6551/ERC6551Registry.sol";

/// @custom:security-contact zitao@placeholdersoft.com
contract GiftedBox is
    IGiftedBox,
    Initializable,
    ERC721HolderUpgradeable,
    ERC721Upgradeable,
    ERC721PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable
{
    using Address for address payable;
    // region defines
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");

    event GiftedBoxSentToVault(
        address indexed from,
        address indexed to,
        address operator,
        uint256 tokenId
    );
    event GiftedBoxClaimed(
        uint256 tokenId,
        GiftingRole role,
        address sender,
        address recipient,
        address operator
    );
    event GiftedBoxClaimedByAdmin(
        uint256 tokenId,
        GiftingRole role,
        address sender,
        address recipient,
        address operator
    );

    event AccountImplUpdated(address indexed newAccountImpl);
    event RegistryUpdated(address indexed newRegistry);
    event GuardianUpdated(address indexed newGuardian);
    event GasSponsorBookUpdated(address indexed newGasSponsorBook);
    event RefundToTokenBoundedAccount(
        address indexed account,
        address indexed from,
        uint256 value
    );
    event GasSponsorEnabled(
        address indexed account,
        uint256 tokenId,
        uint256 ticketId,
        uint256 ticketCount
    );
    event SponsorTicketAdded(
        address indexed account,
        uint256 ticket,
        uint256 value
    );
    // endregion

    // region storage
    uint256 private _nextTokenId;
    mapping(uint256 => GiftingRecord) public giftingRecords;
    GiftedAccount public accountImpl;
    ERC6551Registry public registry;
    GiftedAccountGuardian public guardian;
    IGasSponsorBook public gasSponsorBook;

    // endregion

    // region initializer
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin) public initializer {
        __ERC721_init("GiftedBoxV2", "GB");
        __ERC721Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(CLAIMER_ROLE, defaultAdmin);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // endregion

    // region overrides
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721Upgradeable, ERC721PausableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // endregion

    // region config setter
    function setAccountImpl(
        address payable newAccountImpl
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        accountImpl = GiftedAccount(newAccountImpl);
        emit AccountImplUpdated(address(newAccountImpl));
    }

    function setRegistry(
        address newRegistry
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        registry = ERC6551Registry(newRegistry);
        emit RegistryUpdated(address(newRegistry));
    }

    function setAccountGuardian(
        address newGuardian
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        guardian = GiftedAccountGuardian(newGuardian);
        emit GuardianUpdated(address(newGuardian));
    }

    function setGasSponsorBook(
        address newGasSponsorBook
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        gasSponsorBook = IGasSponsorBook(newGasSponsorBook);
        emit GasSponsorBookUpdated(address(newGasSponsorBook));
    }

    // endregion

    // region view
    function tokenAccountAddress(
        uint256 tokenId
    ) public view returns (address) {
        return
            registry.account(
                address(accountImpl),
                block.chainid,
                address(this),
                tokenId,
                0
            );
    }

    function generateTicketID(address account) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(account)));
    }

    function getGiftingRecord(
        uint256 tokenId
    ) public view returns (GiftingRecord memory) {
        return giftingRecords[tokenId];
    }

    // endregion

    // region internal functions
    function createAccountIfNeeded(
        uint256 tokenId,
        address tokenAccount
    ) internal {
        if (tokenAccount.code.length == 0) {
            registry.createAccount(
                address(accountImpl),
                block.chainid,
                address(this),
                tokenId,
                0,
                abi.encodeWithSignature(
                    "initialize(address)",
                    address(guardian)
                )
            );
        }
    }

    // endregion

    // region gas sponsorship
    function handleSponsorshipAndTransfer(
        address tokenAccount,
        uint256 tokenId
    ) internal {
        uint256 sponserFee = gasSponsorBook.feePerSponsorTicket();
        uint256 numberOfTickets = msg.value / sponserFee;
        if (numberOfTickets > 0) {
            uint256 ticket = generateTicketID(address(tokenAccount));
            uint256 transferFee = sponserFee * numberOfTickets;
            gasSponsorBook.addSponsorTicket{value: transferFee}(ticket);
            uint256 left = msg.value - transferFee;
            if (left > 0) {
                payable(tokenAccount).sendValue(left);
                emit RefundToTokenBoundedAccount(
                    tokenAccount,
                    msg.sender,
                    left
                );
            }
            emit GasSponsorEnabled(
                tokenAccount,
                tokenId,
                ticket,
                numberOfTickets
            );
        } else if (msg.value > 0) {
            uint256 value = msg.value;
            payable(tokenAccount).sendValue(value);
            emit RefundToTokenBoundedAccount(tokenAccount, msg.sender, value);
        }
    }

    /**
     * Adds a sponsor ticket for the given account and token ID, paying the sponsor ticket fee.
     * A sponsor ticket allows the account holder to sponsor a gas refund for transfers of the token ID.
     * The sponsor ticket ID is generated and stored in the gas sponsor book along with the sponsor funds.
     * Emits a SponsorTicketAdded event with details.
     */
    function addSponsorTicket(address account) external payable {
        require(
            msg.value >= gasSponsorBook.feePerSponsorTicket(),
            "Insufficient funds for sponsor ticket"
        );
        uint256 ticket = generateTicketID(account);
        gasSponsorBook.addSponsorTicket{value: msg.value}(ticket);
        emit SponsorTicketAdded(account, ticket, msg.value);
    }

    /**
     * @dev Checks if a given NFT token has a sponsor ticket.
     * @param tokenId The ID of the NFT token.
     * @return A boolean indicating whether the NFT token has a sponsor ticket or not.
     */
    function sponsorTickets(uint256 tokenId) public view returns (uint256) {
        if (address(gasSponsorBook) == address(0)) {
            return 0;
        }
        address tokenAccount = registry.account(
            address(accountImpl),
            block.chainid,
            address(this),
            tokenId,
            0
        );
        uint256 ticket = generateTicketID(tokenAccount);
        return gasSponsorBook.sponsorTickets(ticket);
    }

    function feePerSponsorTicket() public view returns (uint256) {
        return gasSponsorBook.feePerSponsorTicket();
    }

    // endregion

    // region Gifting Actions

    /**
     * @notice Sends a gift to the specified recipient.
     * @dev Mints a new token, updates the gifting records, and emits an event.
     * @param recipient The address of the recipient who will receive the gift.
     */
    function sendGift(
        address sender,
        address recipient
    ) public payable whenNotPaused {
        require(sender != address(0), "!sender-address-0");
        require(sender != recipient, "!sender-recipient-same");

        uint256 tokenId = _nextTokenId++;
        _safeMint(sender, tokenId);
        _update(address(this), tokenId, address(0));

        giftingRecords[tokenId] = GiftingRecord({
            operator: msg.sender,
            sender: sender,
            recipient: recipient
        });

        address tokenAccount = registry.account(
            address(accountImpl),
            block.chainid,
            address(this),
            tokenId,
            0
        );
        createAccountIfNeeded(tokenId, tokenAccount);
        handleSponsorshipAndTransfer(tokenAccount, tokenId);

        emit GiftedBoxSentToVault(sender, recipient, msg.sender, tokenId);
    }

    function claimGift(uint256 tokenId, GiftingRole role) public whenNotPaused {
        GiftingRecord memory record = giftingRecords[tokenId];
        if (role == GiftingRole.SENDER) {
            require(record.sender == msg.sender, "!not-sender");
        } else if (role == GiftingRole.RECIPIENT) {
            require(record.recipient == msg.sender, "!not-recipient");
        } else {
            revert("!invalid-role");
        }

        delete giftingRecords[tokenId];
        _update(msg.sender, tokenId, address(0));
        emit GiftedBoxClaimed(
            tokenId,
            role,
            record.sender,
            record.recipient,
            record.operator
        );
    }

    function claimGiftByClaimer(
        uint256 tokenId,
        GiftingRole role
    ) public onlyRole(CLAIMER_ROLE) {
        GiftingRecord memory record = giftingRecords[tokenId];
        if (role == GiftingRole.SENDER) {
            require(record.sender != address(0), "!invalid-sender");
            _update(record.sender, tokenId, address(0));
        } else if (role == GiftingRole.RECIPIENT) {
            require(record.recipient != address(0), "!invalid-recipient");
            _update(record.recipient, tokenId, address(0));
        } else {
            revert("!invalid-role");
        }

        delete giftingRecords[tokenId];
        emit GiftedBoxClaimedByAdmin(
            tokenId,
            role,
            record.sender,
            record.recipient,
            record.operator
        );
    }

    function claimGiftByClaimerConsumeSponsorTicket(
        uint256 tokenId,
        GiftingRole role
    ) public onlyRole(CLAIMER_ROLE) {
        require(address(gasSponsorBook) != address(0), "!gas-sponsor-not-set");
        require(sponsorTickets(tokenId) > 0, "!sponsor-ticket-not-enough");
        address tokenAccount = tokenAccountAddress(tokenId);
        uint256 ticketId = generateTicketID(tokenAccount);
        gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
        claimGiftByClaimer(tokenId, role);
    }

    // endregion Gifting Actions

    // region Forward Methods
    function transferERC721PermitMessage(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        address to,
        uint256 deadline
    ) external view returns (string memory) {
        IGiftedAccount account = IGiftedAccount(
            tokenAccountAddress(giftedBoxTokenId)
        );
        return
            account.getTransferERC721PermitMessage(
                tokenContract,
                tokenId,
                to,
                deadline
            );
    }

    function transferERC721(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IGiftedAccount account = IGiftedAccount(
            tokenAccountAddress(giftedBoxTokenId)
        );

        account.transferERC721(tokenContract, tokenId, to, deadline, v, r, s);
    }

    function transferERC721Sponsor(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        address tokenAccount = tokenAccountAddress(giftedBoxTokenId);
        uint256 ticketId = generateTicketID(tokenAccount);
        require(address(gasSponsorBook) != address(0), "!gas-sponsor-not-set");
        require(
            sponsorTickets(giftedBoxTokenId) > 0,
            "!sponsor-ticket-not-enough"
        );
        gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
        IGiftedAccount(tokenAccount).transferERC721(
            tokenContract,
            tokenId,
            to,
            deadline,
            v,
            r,
            s
        );
    }

    function transferERC1155PermitMessage(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address to,
        uint256 deadline
    ) external view returns (string memory) {
        IGiftedAccount account = IGiftedAccount(
            tokenAccountAddress(giftedBoxTokenId)
        );
        return
            account.getTransferERC1155PermitMessage(
                tokenContract,
                tokenId,
                amount,
                to,
                deadline
            );
    }

    function transferERC1155(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IGiftedAccount account = IGiftedAccount(
            tokenAccountAddress(giftedBoxTokenId)
        );

        account.transferERC1155(
            tokenContract,
            tokenId,
            amount,
            to,
            deadline,
            v,
            r,
            s
        );
    }

    function transferERC1155Sponsor(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        address tokenAccount = tokenAccountAddress(giftedBoxTokenId);
        uint256 ticketId = generateTicketID(tokenAccount);
        require(address(gasSponsorBook) != address(0), "!gas-sponsor-not-set");
        require(
            sponsorTickets(giftedBoxTokenId) > 0,
            "!sponsor-ticket-not-enough"
        );
        gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
        IGiftedAccount(tokenAccount).transferERC1155(
            tokenContract,
            tokenId,
            amount,
            to,
            deadline,
            v,
            r,
            s
        );
    }

    // endregion Forward Methods
}