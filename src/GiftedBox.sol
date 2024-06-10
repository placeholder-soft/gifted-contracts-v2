// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

/// @custom:security-contact zitao@placeholdersoft.com
contract GiftedBox is
    Initializable,
    ERC721HolderUpgradeable,
    ERC721Upgradeable,
    ERC721PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable
{
    // region defines
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant CLAIM_ADMIN_ROLE = keccak256("CLAIM_ADMIN_ROLE");

    struct GiftingRecord {
        address sender;
        address recipient;
    }

    event GiftedBoxSentToVault(
        address indexed from,
        address indexed to,
        uint256 tokenId
    );
    event GiftBoxClaimed(
        uint256 tokenId,
        address indexed claimer,
        bool asSender
    );
    event GiftBoxClaimedByAdmin(
        uint256 tokenId,
        address indexed claimer,
        bool asSender,
        address indexed admin
    );
    // endregion

    // region storage
    uint256 private _nextTokenId;
    mapping(uint256 => GiftingRecord) public giftingRecords;

    // endregion

    // region initializer
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin
    ) public initializer {
        __ERC721_init("GiftBoxV2", "GB");
        __ERC721Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(CLAIM_ADMIN_ROLE, defaultAdmin);
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

    // region Gifting Actions

    /**
     * @notice Sends a gift to the specified recipient.
     * @dev Mints a new token, updates the gifting records, and emits an event.
     * @param recipient The address of the recipient who will receive the gift.
     */
    function sendGift(address recipient) public {
        uint256 tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        _update(address(this), tokenId, recipient);

        giftingRecords[tokenId] = GiftingRecord({
            sender: msg.sender,
            recipient: recipient
        });

        emit GiftedBoxSentToVault(msg.sender, recipient, tokenId);
    }


    /**
     * @notice Resends a gift to a new recipient.
     * @param tokenId The ID of the token to resend.
     * @param recipient The address of the new recipient.
     */
    function resendGift(uint256 tokenId, address recipient) public {
        safeTransferFrom(address(msg.sender), address(this), tokenId);

        giftingRecords[tokenId] = GiftingRecord({
            sender: msg.sender,
            recipient: recipient
        });

        emit GiftedBoxSentToVault(msg.sender, recipient, tokenId);
    }

    /**
     * @notice Claims a gift.
     * @param tokenId The ID of the token to claim.
     * @param asSender Boolean indicating if the sender is claiming the gift.
     */
    function claimGift(uint256 tokenId, bool asSender) public {
        GiftingRecord memory record = giftingRecords[tokenId];
        if (asSender) {
            require(record.sender == msg.sender, "!not-sender");
        } else {
            require(record.recipient == msg.sender, "!not-recipient");
        }

        delete giftingRecords[tokenId];
        _update(msg.sender, tokenId, address(this));
        emit GiftBoxClaimed(tokenId, msg.sender, asSender);
    }


    /**
     * @notice Allows an admin to claim a gift to sender or recipient
     * @param tokenId The ID of the token to be claimed.
     * @param claimer The address of the user claiming the gift.
     * @param toSender A boolean indicating if the gift should be claimed to the sender.
     */
    function claimGiftByAdmin(
        uint256 tokenId,
        address claimer,
        bool toSender
    ) public onlyRole(CLAIM_ADMIN_ROLE) {
        GiftingRecord memory record = giftingRecords[tokenId];
        if (toSender) {
            require(record.sender == claimer, "!not-sender");
        } else {
            require(record.recipient == claimer, "!not-recipient");
        }

        delete giftingRecords[tokenId];
        _update(claimer, tokenId, address(this));
        emit GiftBoxClaimed(tokenId, claimer, toSender);
        emit GiftBoxClaimedByAdmin(tokenId, claimer, toSender, msg.sender);
    }


    // endregion
}
