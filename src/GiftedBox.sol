// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import { GiftedAccount } from "./GiftedAccount.sol";
import "./GiftedAccountGuardian.sol";
import "./interfaces/IGasSponsorBook.sol";
import "./interfaces/IGiftedBox.sol";
import "./interfaces/IGiftedAccount.sol";
import "./erc6551/ERC6551Registry.sol";

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

  // region Constants
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
  bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");
  // endregion

  // region Events
  event GiftedBoxSentToVault(address indexed from, address indexed to, address operator, uint256 tokenId);
  event GiftedBoxClaimed(uint256 tokenId, GiftingRole role, address sender, address recipient, address operator);
  event GiftedBoxClaimedByAdmin(uint256 tokenId, GiftingRole role, address sender, address recipient, address operator);
  event AccountImplUpdated(address indexed newAccountImpl);
  event RegistryUpdated(address indexed newRegistry);
  event GasSponsorBookUpdated(address indexed newGasSponsorBook);
  event RefundToTokenBoundedAccount(address indexed account, address indexed from, uint256 value);
  event GasSponsorEnabled(address indexed account, uint256 tokenId, uint256 ticketId, uint256 ticketCount);
  event SponsorTicketAdded(address indexed account, uint256 ticket, uint256 value);
  event MintingFeePaid(
    address indexed payer, address sender, address recipient, address operator, uint256 tokenId, uint256 fee
  );
  event VaultUpdated(address indexed newVault);
  event UnifiedStoreUpdated(address indexed newUnifiedStore);
  event TransferERC20Permit(
    uint256 indexed giftedBoxTokenId,
    address indexed from,
    address indexed to,
    address tokenContract,
    uint256 amount,
    uint256 deadline,
    address signer,
    address relayer
  );
  event TransferEtherPermit(
    uint256 indexed giftedBoxTokenId,
    address indexed from,
    address indexed to,
    uint256 amount,
    uint256 deadline,
    address signer,
    address relayer
  );
  event AccountBytecodeHashUpdated(bytes32 indexed newAccountBytecodeHash);
  // endregion

  // region Storage
  uint256 private _nextTokenId;
  mapping(uint256 => GiftingRecord) public giftingRecords;
  GiftedAccount public accountImpl;
  ERC6551Registry public registry;
  GiftedAccountGuardian public guardian; // guardian is deprecated
  IGasSponsorBook public gasSponsorBook;
  IVault public vault;
  bytes32 public accountBytecodeHash;

  // added unifed store on swap upgrade
  IUnifiedStore public unifiedStore;

  // endregion

  // region Constructor & Initializer
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

  function setAccountBytecodeHash(bytes32 _bytecodeHash) public onlyRole(DEFAULT_ADMIN_ROLE) {
    accountBytecodeHash = _bytecodeHash;
    emit AccountBytecodeHashUpdated(_bytecodeHash);
  }

  // endregion

  // region Admin Functions
  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

  function setAccountImpl(address payable newAccountImpl) public onlyRole(DEFAULT_ADMIN_ROLE) {
    accountImpl = GiftedAccount(newAccountImpl);
    emit AccountImplUpdated(address(newAccountImpl));
  }

  function setRegistry(address newRegistry) public onlyRole(DEFAULT_ADMIN_ROLE) {
    registry = ERC6551Registry(newRegistry);
    emit RegistryUpdated(address(newRegistry));
  }

  function setGasSponsorBook(address newGasSponsorBook) public onlyRole(DEFAULT_ADMIN_ROLE) {
    gasSponsorBook = IGasSponsorBook(newGasSponsorBook);
    emit GasSponsorBookUpdated(address(newGasSponsorBook));
  }

  function setVault(address newVault) public onlyRole(DEFAULT_ADMIN_ROLE) {
    vault = IVault(newVault);
    emit VaultUpdated(address(newVault));
  }

  function setUnifiedStore(address newUnifiedStore) public onlyRole(DEFAULT_ADMIN_ROLE) {
    unifiedStore = IUnifiedStore(newUnifiedStore);
    emit UnifiedStoreUpdated(address(newUnifiedStore));
  }

  // endregion

  // region Core ERC721 Functions
  function _update(address to, uint256 tokenId, address auth)
    internal
    override(ERC721Upgradeable, ERC721PausableUpgradeable)
    returns (address)
  {
    return super._update(to, tokenId, auth);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721Upgradeable, AccessControlUpgradeable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  // endregion

  // region View Functions
  function calculateSalt(uint256 tokenId) public view returns (bytes32) {
    // First 20 bytes must be zeros to pass factory validation
    return bytes32(
      uint256(keccak256(abi.encode(block.chainid, address(this), accountBytecodeHash, tokenId))) & ((1 << 96) - 1)
    ); // Only keep last 12 bytes, first 20 bytes will be zeros
  }

  function tokenAccountAddress(uint256 tokenId) public view returns (address) {
    return registry.account(calculateSalt(tokenId));
  }

  function generateTicketID(address account) public pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(account)));
  }

  function getGiftingRecord(uint256 tokenId) public view returns (GiftingRecord memory) {
    return giftingRecords[tokenId];
  }

  /**
   * @dev Checks if a given GiftedBox has a sponsor ticket.
   * @param tokenId The ID of the GiftedBox.
   * @return A boolean indicating whether the GiftedBox has a sponsor ticket or not.
   */
  function sponsorTickets(uint256 tokenId) public view returns (uint256) {
    if (address(gasSponsorBook) == address(0)) {
      return 0;
    }
    address tokenAccount = registry.account(calculateSalt(tokenId));
    uint256 ticket = generateTicketID(tokenAccount);
    return gasSponsorBook.sponsorTickets(ticket);
  }

  function feePerSponsorTicket() public view returns (uint256) {
    return gasSponsorBook.feePerSponsorTicket();
  }

  // endregion

  // region Internal Functions
  function createAccountIfNeeded(uint256 tokenId, address tokenAccount) internal {
    require(accountBytecodeHash != bytes32(0), "!bytecode-hash-not-set");
    require(address(registry) != address(0), "!registry-not-set");
    require(address(accountImpl) != address(0), "!account-impl-not-set");
    if (tokenAccount.code.length == 0) {
      registry.createAccount(
        address(accountImpl),
        accountBytecodeHash,
        calculateSalt(tokenId),
        abi.encodeWithSignature(
          "initialize(address,uint256,address,uint256)", address(unifiedStore), block.chainid, address(this), tokenId
        )
      );
    }
  }

  function handleSponsorshipAndTransfer(address tokenAccount, uint256 tokenId, uint256 value) internal {
    uint256 sponserFee = gasSponsorBook.feePerSponsorTicket();
    uint256 numberOfTickets = value / sponserFee;
    if (numberOfTickets > 0) {
      uint256 ticket = generateTicketID(address(tokenAccount));
      uint256 transferFee = sponserFee * numberOfTickets;
      gasSponsorBook.addSponsorTicket{ value: transferFee }(ticket);
      uint256 left = value - transferFee;
      if (left > 0) {
        payable(tokenAccount).sendValue(left);
        emit RefundToTokenBoundedAccount(tokenAccount, msg.sender, left);
      }
      emit GasSponsorEnabled(tokenAccount, tokenId, ticket, numberOfTickets);
    } else if (value > 0) {
      payable(tokenAccount).sendValue(value);
      emit RefundToTokenBoundedAccount(tokenAccount, msg.sender, value);
    }
  }

  // endregion

  // region Gas Sponsorship
  /**
   * Adds a sponsor ticket for the given account and token ID, paying the sponsor ticket fee.
   * A sponsor ticket allows the account holder to sponsor a gas refund for transfers of the token ID.
   * The sponsor ticket ID is generated and stored in the gas sponsor book along with the sponsor funds.
   * Emits a SponsorTicketAdded event with details.
   */
  function addSponsorTicket(address account) external payable {
    require(msg.value >= gasSponsorBook.feePerSponsorTicket(), "Insufficient funds for sponsor ticket");
    uint256 ticket = generateTicketID(account);
    gasSponsorBook.addSponsorTicket{ value: msg.value }(ticket);
    emit SponsorTicketAdded(account, ticket, msg.value);
  }

  // endregion

  // region Gifting Core
  /**
   * @notice Sends a gift to the specified recipient.
   * @dev Mints a new token, updates the gifting records, and emits an event.
   * @param recipient The address of the recipient who will receive the gift.
   */
  function sendGift(address sender, address recipient, address operator, uint256 mintingFee)
    public
    payable
    whenNotPaused
  {
    require(sender != address(0), "!sender-address-0");
    require(sender != recipient, "!sender-recipient-same");

    uint256 tokenId = _nextTokenId++;
    _safeMint(sender, tokenId);
    _update(address(this), tokenId, address(0));

    if (mintingFee > 0) {
      require(address(vault) != address(0), "!vault-not-set");
      vault.transferIn{ value: mintingFee }(address(0), msg.sender, mintingFee);
      emit MintingFeePaid(msg.sender, sender, recipient, operator, tokenId, mintingFee);
    }

    giftingRecords[tokenId] = GiftingRecord({ operator: operator, sender: sender, recipient: recipient });

    bytes32 salt = calculateSalt(tokenId);
    address tokenAccount = registry.account(salt);
    createAccountIfNeeded(tokenId, tokenAccount);
    handleSponsorshipAndTransfer(tokenAccount, tokenId, msg.value - mintingFee);

    emit GiftedBoxSentToVault(sender, recipient, operator, tokenId);
  }

  function sendGift(address sender, address recipient, address operator) public payable whenNotPaused {
    sendGift(sender, recipient, operator, 0);
  }

  function sendGift(address sender, address recipient) public payable whenNotPaused {
    sendGift(sender, recipient, msg.sender, 0);
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
    emit GiftedBoxClaimed(tokenId, role, record.sender, record.recipient, record.operator);
  }

  function claimGiftByClaimer(uint256 tokenId, GiftingRole role) public onlyRole(CLAIMER_ROLE) {
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
    emit GiftedBoxClaimedByAdmin(tokenId, role, record.sender, record.recipient, record.operator);
  }

  function claimGiftByClaimerConsumeSponsorTicket(uint256 tokenId, GiftingRole role) public onlyRole(CLAIMER_ROLE) {
    require(address(gasSponsorBook) != address(0), "!gas-sponsor-not-set");
    require(sponsorTickets(tokenId) > 0, "!sponsor-ticket-not-enough");
    address tokenAccount = tokenAccountAddress(tokenId);
    uint256 ticketId = generateTicketID(tokenAccount);
    gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
    claimGiftByClaimer(tokenId, role);
  }

  // endregion Gifting Core

  // region Token Transfers
  function transferERC721PermitMessage(
    uint256 giftedBoxTokenId,
    address tokenContract,
    uint256 tokenId,
    address to,
    uint256 deadline
  ) external view returns (string memory) {
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));
    return account.getTransferERC721PermitMessage(tokenContract, tokenId, to, deadline);
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
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));

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
    require(sponsorTickets(giftedBoxTokenId) > 0, "!sponsor-ticket-not-enough");
    gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
    IGiftedAccount(tokenAccount).transferERC721(tokenContract, tokenId, to, deadline, v, r, s);
  }

  function transferERC1155PermitMessage(
    uint256 giftedBoxTokenId,
    address tokenContract,
    uint256 tokenId,
    uint256 amount,
    address to,
    uint256 deadline
  ) external view returns (string memory) {
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));
    return account.getTransferERC1155PermitMessage(tokenContract, tokenId, amount, to, deadline);
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
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));

    account.transferERC1155(tokenContract, tokenId, amount, to, deadline, v, r, s);
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
    require(sponsorTickets(giftedBoxTokenId) > 0, "!sponsor-ticket-not-enough");
    gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
    IGiftedAccount(tokenAccount).transferERC1155(tokenContract, tokenId, amount, to, deadline, v, r, s);
  }

  function transferERC20PermitMessage(
    uint256 giftedBoxTokenId,
    address tokenContract,
    uint256 amount,
    address to,
    uint256 deadline
  ) external view returns (string memory) {
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));
    return account.getTransferERC20PermitMessage(tokenContract, amount, to, deadline);
  }

  function transferERC20(
    uint256 giftedBoxTokenId,
    address tokenContract,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));

    account.transferERC20(tokenContract, amount, to, deadline, v, r, s);
  }

  function transferERC20Sponsor(
    uint256 giftedBoxTokenId,
    address tokenContract,
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
    require(sponsorTickets(giftedBoxTokenId) > 0, "!sponsor-ticket-not-enough");
    gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
    IGiftedAccount(tokenAccount).transferERC20(tokenContract, amount, to, deadline, v, r, s);
  }

  function transferEtherPermitMessage(uint256 giftedBoxTokenId, uint256 amount, address to, uint256 deadline)
    external
    view
    returns (string memory)
  {
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));
    return account.getTransferEtherPermitMessage(amount, to, deadline);
  }

  function transferEther(
    uint256 giftedBoxTokenId,
    uint256 amount,
    address payable to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));

    account.transferEther(to, amount, deadline, v, r, s);
  }

  function transferEtherSponsor(
    uint256 giftedBoxTokenId,
    uint256 amount,
    address payable to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    address tokenAccount = tokenAccountAddress(giftedBoxTokenId);
    uint256 ticketId = generateTicketID(tokenAccount);
    require(address(gasSponsorBook) != address(0), "!gas-sponsor-not-set");
    require(sponsorTickets(giftedBoxTokenId) > 0, "!sponsor-ticket-not-enough");
    gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
    IGiftedAccount(tokenAccount).transferEther(to, amount, deadline, v, r, s);
  }
  // endregion Token Transfers

  // region Batch Transfers

  function batchTransferPermitMessage(uint256 giftedBoxTokenId, bytes[] calldata data, uint256 deadline)
    external
    view
    returns (string memory)
  {
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));
    return account.getBatchTransferPermitMessage(data, deadline);
  }

  function batchTransfer(
    uint256 giftedBoxTokenId,
    bytes[] calldata data,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    IGiftedAccount account = IGiftedAccount(tokenAccountAddress(giftedBoxTokenId));

    account.batchTransfer(data, deadline, v, r, s);
  }

  function batchTransferSponsor(
    uint256 giftedBoxTokenId,
    bytes[] calldata data,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    address tokenAccount = tokenAccountAddress(giftedBoxTokenId);
    uint256 ticketId = generateTicketID(tokenAccount);
    require(address(gasSponsorBook) != address(0), "!gas-sponsor-not-set");
    require(sponsorTickets(giftedBoxTokenId) > 0, "!sponsor-ticket-not-enough");
    gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
    IGiftedAccount(tokenAccount).batchTransfer(data, deadline, v, r, s);
  }

  // endregion

  // region Token Conversions
  function quoteUSDCToETH(uint256 giftedBoxTokenId, uint256 percent)
    external
    returns (uint256 expectedOutput, uint256 amountIn, uint256 amountNoSwap)
  {
    address tokenAccount = tokenAccountAddress(giftedBoxTokenId);
    (expectedOutput, amountIn, amountNoSwap) = IGiftedAccount(payable(tokenAccount)).quoteUSDCToETH(percent);
  }

  function convertUSDCToETHAndSend(uint256 giftedBoxTokenId, uint256 percent, uint256 minAmountOut, address recipient)
    external
    payable
  {
    address tokenAccount = tokenAccountAddress(giftedBoxTokenId);
    IGiftedAccount(payable(tokenAccount)).convertUSDCToETHAndSend(percent, minAmountOut, recipient);
  }

  function getConvertUSDCToETHAndSendPermitMessage(
    uint256 giftedBoxTokenId,
    uint256 percent,
    uint256 minAmountOut,
    address recipient,
    uint256 deadline
  ) external view returns (string memory) {
    address tokenAccount = tokenAccountAddress(giftedBoxTokenId);
    return IGiftedAccount(payable(tokenAccount)).getConvertUSDCToETHAndSendPermitMessage(
      percent, minAmountOut, recipient, deadline
    );
  }

  function convertUSDCToETHAndSendSponsor(
    uint256 giftedBoxTokenId,
    uint256 percent,
    uint256 minAmountOut,
    address recipient,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    address tokenAccount = tokenAccountAddress(giftedBoxTokenId);
    uint256 ticketId = generateTicketID(tokenAccount);
    require(address(gasSponsorBook) != address(0), "!gas-sponsor-not-set");
    require(sponsorTickets(giftedBoxTokenId) > 0, "!sponsor-ticket-not-enough");
    gasSponsorBook.consumeSponsorTicket(ticketId, msg.sender);
    IGiftedAccount(payable(tokenAccount)).convertUSDCToETHAndSend(percent, minAmountOut, recipient, deadline, v, r, s);
  }
  // endregion
}
