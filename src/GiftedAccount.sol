// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/utils/introspection/IERC165.sol";
import "@openzeppelin/utils/Strings.sol";
import "@openzeppelin/utils/Address.sol";
import "@openzeppelin/utils/cryptography/SignatureChecker.sol";

import "@openzeppelin/token/ERC721/IERC721.sol";
import "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/interfaces/IERC1271.sol";
import "@openzeppelin/token/ERC1155/IERC1155.sol";
import "./erc6551/interfaces/IERC6551Account.sol";
import "./erc6551/evm/lib/ERC6551AccountLib.sol";
import "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IGiftedAccountGuardian.sol";
import "./interfaces/IGiftedAccount.sol";
import "./interfaces/IGiftedBox.sol";
import "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/utils/cryptography/ECDSA.sol";
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IUnifiedStore.sol";
import "./interfaces/IQuoter.sol";
import "./interfaces/IWETH.sol"; // Added IWETH interface

error UntrustedImplementation();
error NotAuthorized();

contract GiftedAccount is
  IERC165,
  IERC1271,
  IERC721Receiver,
  IERC1155Receiver,
  IERC6551Account,
  IGiftedAccount,
  Initializable
{
  using Strings for uint256;
  using Strings for address;
  // region Storage

  /// @dev _guardian is deprecated, the var is kept for maintaining storage layout
  // @deprecated
  IGiftedAccountGuardian private _guardian;

  uint256 public _nonce;

  IUnifiedStore private _unifiedStore;

  // endregion

  function initialize(address unifiedStore) public initializer {
    _unifiedStore = IUnifiedStore(unifiedStore);
  }

  function getGuardian() public view returns (IGiftedAccountGuardian) {
    return IGiftedAccountGuardian(getUnifiedStore().getAddress("GiftedAccountGuardian"));
  }

  function getUnifiedStore() public view returns (IUnifiedStore) {
    if (address(_unifiedStore) == address(0)) {
      // handle upgrade scenario in the case where _unifiedStore is not initialized
      // due to the upgrade
      if (block.chainid == 1) {
        return IUnifiedStore(0xb1B46db99b18F00c15605Bb2BA15da26E7Db22bB);
      } else if (block.chainid == 8453) {
        return IUnifiedStore(0xc45f19217e064EcE272e55EE7aAD36cc91e7ADA3);
      } else if (block.chainid == 42161) {
        return IUnifiedStore(0x6A9AB4532a1AD2441238125A966033e4Aa859b0A);
      } else if (block.chainid == 11155111) {
        return IUnifiedStore(0x09748F6411a4D1A84a87645A3E406dCb3c31Fc73);
      } else {
        revert("!unified-store-zero-address");
      }
    }
    return _unifiedStore;
  }

  /// @dev owner is free to change the unified store which removes centralization control
  function setUnifiedStore(address unifiedStore) public onlyOwner {
    _unifiedStore = IUnifiedStore(unifiedStore);
    emit UnifiedStoreUpdated(address(_unifiedStore), address(unifiedStore));
  }

  // region Events

  event UnifiedStoreUpdated(address indexed oldAddress, address indexed newAddress);

  event CallPermit(address indexed owner, address indexed to, uint256 nonce, uint256 deadline);

  // Event to log the transfer of an ERC1155 token with a permit
  event TransferERC1155Permit(
    address indexed from,
    address indexed to,
    address indexed tokenContract,
    uint256 tokenId,
    uint256 amount,
    uint256 deadline,
    uint256 nonce,
    address signer,
    address relayer
  );
  /// @notice Emitted when ETH is added to the account
  /// @param sender The address that sent the ETH
  /// @param amount The amount of ETH sent
  /// @param newBalance The new balance of the account
  event ReceivedEther(address indexed sender, uint256 amount, uint256 newBalance);

  event GiftedAccountERC1155Received(
    address operator,
    address from,
    uint256 erc1155TokenId,
    uint256 erc1155Tokenvalue,
    address erc1155Contract,
    address giftedBoxContract,
    uint256 giftedBoxTokenId
  );

  event GiftedAccountERC721Received(
    address operator,
    address from,
    uint256 erc721TokenId,
    address erc721Contract,
    address giftedBoxContract,
    uint256 giftedBoxTokenId
  );

  event TransferERC721Permit(
    address indexed from,
    address indexed to,
    address indexed nft,
    uint256 tokenId,
    uint256 deadline,
    uint256 nonce,
    address signer,
    address relayer
  );

  event TransferERC20Permit(
    address indexed from,
    address indexed to,
    address indexed tokenContract,
    uint256 amount,
    uint256 deadline,
    uint256 nonce,
    address signer,
    address relayer
  );

  event TransferEtherPermit(
    address indexed from,
    address indexed to,
    uint256 amount,
    uint256 deadline,
    uint256 nonce,
    address signer,
    address relayer
  );

  event BatchTransferPermit(address indexed signer, bytes[] data, uint256 deadline, uint256 nonce);
  // endregion Events

  // region modifier

  /// @dev reverts if caller is not authorized to execute on this account
  modifier onlyAuthorized() {
    if (!isAuthorized(msg.sender)) revert NotAuthorized();
    _;
  }

  modifier onlyOwner() {
    if (msg.sender != owner()) revert NotAuthorized();
    _;
  }

  // endregion

  // region ERC6551
  receive() external payable { }

  fallback() external payable {
    emit ReceivedEther(msg.sender, msg.value, address(this).balance);
  }

  function executeCall(address to, uint256 value, bytes calldata data)
    external
    payable
    onlyAuthorized
    returns (bytes memory result)
  {
    return call(to, value, data);
  }

  function executeCalls(address[] calldata to, uint256[] calldata value, bytes[] calldata data)
    external
    payable
    onlyAuthorized
    returns (bytes[] memory results)
  {
    require(to.length == value.length && value.length == data.length, "!length-mismatch");
    results = new bytes[](to.length);

    for (uint256 i = 0; i < to.length; i++) {
      results[i] = call(to[i], value[i], data[i]);
    }

    return results;
  }

  function token() public view returns (uint256, address, uint256) {
    return ERC6551AccountLib.token();
  }

  function nonce() public view returns (uint256) {
    return _nonce;
  }

  function owner() public view returns (address) {
    (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
    if (chainId != block.chainid) {
      revert("!chainid-not-equal-block-chainid");
    }

    return IERC721(tokenContract).ownerOf(tokenId);
  }

  // endregion

  // region ERC165
  function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
    return (
      interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
        || interfaceId == type(IERC6551Account).interfaceId
    );
  }

  // endregion

  // region ERC1271
  function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
    bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);

    if (isValid) {
      return IERC1271.isValidSignature.selector;
    }
    return "";
  }

  // endregion

  // region ERC721Receiver
  function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata)
    external
    override
    returns (bytes4)
  {
    address _owner = owner();
    (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
    if (chainId != block.chainid) {
      revert("!chainid-not-equal-block-chainid");
    }

    if (_owner == _from || _owner == _operator || isAuthorizedSender(_from, _operator, tokenContract, tokenId)) {
      emit GiftedAccountERC721Received(_operator, _from, _tokenId, msg.sender, tokenContract, tokenId);
      return IERC721Receiver.onERC721Received.selector;
    }

    revert("!sender-not-authorized");
  }

  function isAuthorizedSender(address _from, address _operator, address tokenContract, uint256 tokenId)
    internal
    view
    returns (bool)
  {
    GiftingRecord memory record = IGiftedBox(tokenContract).getGiftingRecord(tokenId);
    return
      (record.operator == _from || record.operator == _operator || record.sender == _from || record.sender == _operator);
  }

  // endregion

  // region ERC1155Receiver
  function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata)
    external
    override
    returns (bytes4)
  {
    address _owner = owner();
    (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
    if (chainId != block.chainid) {
      revert("!chainid-not-equal-block-chainid");
    }

    if (_owner == _from || _owner == _operator || isAuthorizedSender(_from, _operator, tokenContract, tokenId)) {
      emit GiftedAccountERC1155Received(_operator, _from, _id, _value, msg.sender, tokenContract, tokenId);
      return IERC1155Receiver.onERC1155Received.selector;
    }

    revert("!sender-not-authorized");
  }

  function onERC1155BatchReceived(
    address _operator,
    address _from,
    uint256[] calldata _ids,
    uint256[] calldata _values,
    bytes calldata
  ) external override returns (bytes4) {
    address _owner = owner();
    (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
    if (chainId != block.chainid) {
      revert("!chainid-not-equal-block-chainid");
    }

    if (_owner == _from || _owner == _operator || isAuthorizedSender(_from, _operator, tokenContract, tokenId)) {
      for (uint256 i = 0; i < _ids.length; i++) {
        emit GiftedAccountERC1155Received(_operator, _from, _ids[i], _values[i], msg.sender, tokenContract, tokenId);
      }
      return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    revert("!sender-not-authorized");
  }

  // endregion

  // region EIP 712
  /// domain separator

  function name() public pure returns (string memory) {
    return "GiftedAccount";
  }

  // Returns the domain separator, updating it if chainID changes
  function domainSeparator() public view returns (bytes32) {
    return keccak256(
      abi.encode(
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
        keccak256(bytes(name())),
        keccak256(bytes("1")),
        block.chainid,
        address(this)
      )
    );
  }

  // endregion

  // region misc
  /// @dev Returns the authorization status for a given caller
  function isAuthorized(address caller) public view returns (bool) {
    if (caller == owner()) return true;

    IGiftedAccountGuardian guardian = getGuardian();
    if (address(guardian) != address(0) && guardian.isExecutor(caller)) {
      return true;
    }

    return false;
  }

  /// @dev check if it is the token owner of the account
  function isOwner(address caller) public view returns (bool) {
    return caller == owner();
  }

  // endregion

  // region internal
  function _incrementNonce() internal {
    _nonce++;
  }

  function call(address to, uint256 value, bytes calldata data) internal returns (bytes memory result) {
    _incrementNonce();

    emit TransactionExecuted(to, value, data);

    bool success;
    (success, result) = to.call{ value: value }(data);

    if (!success) {
      assembly {
        revert(add(result, 32), mload(result))
      }
    }
  }

  function _recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
    // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
    // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
    // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
    // signatures from current libraries generate a unique signature with an s-value in the lower half order.
    //
    // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
    // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
    // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
    // these malleable signatures as well.
    if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
      revert("ECDSA: invalid signature 's' value");
    }

    if (v != 27 && v != 28) {
      revert("ECDSA: invalid signature 'v' value");
    }

    // If the signature is valid (and not malleable), return the signer address
    address signer = ecrecover(hash, v, r, s);
    require(signer != address(0), "ECDSA: invalid signature");

    return signer;
  }

  // d83869c5bb54ba35eb2fa505a0206fde32206a3325ac92b027126dca04d8cdae
  bytes32 public constant CALL_PERMIT_TYPEHASH =
    keccak256("CallPermit(address to, uint256 value, byte data, uint256 deadline, uint256 nonce)");

  function _bytesArrayToString(bytes[] memory data) internal pure returns (string memory) {
    bytes memory result;
    for (uint256 i = 0; i < data.length; i++) {
      bytes memory hexString;
      if (data[i].length > 32) {
        bytes32 hash = keccak256(data[i]);
        hexString = abi.encodePacked("0x", _toHexString(hash));
      } else {
        hexString = abi.encodePacked("0x", _toHexString(bytes32(data[i])));
      }
      result = abi.encodePacked(result, hexString);
      if (i < data.length - 1) {
        result = abi.encodePacked(result, ",");
      }
    }
    return string(result);
  }

  function _toHexString(bytes32 value) internal pure returns (string memory) {
    bytes memory alphabet = "0123456789abcdef";
    bytes memory str = new bytes(64);
    for (uint256 i = 0; i < 32; i++) {
      str[i * 2] = alphabet[uint8(value[i] >> 4)];
      str[1 + i * 2] = alphabet[uint8(value[i] & 0x0f)];
    }
    return string(str);
  }

  // endregion

  // region external

  function hashTypedCallPermit(address to, uint256 value, bytes calldata data, uint256 deadline)
    public
    view
    returns (bytes32 callHash)
  {
    bytes32 hashStruct = keccak256(abi.encode(CALL_PERMIT_TYPEHASH, to, value, data, deadline, nonce()));
    bytes32 eip712DomainHash = domainSeparator();
    callHash = keccak256(abi.encodePacked(uint16(0x1901), eip712DomainHash, hashStruct));
  }

  function hashTypedCallPermit(address to, uint256 value, bytes calldata data, uint256 deadline, uint256 encodeNonce)
    public
    view
    returns (bytes32 callHash)
  {
    bytes32 hashStruct = keccak256(abi.encode(CALL_PERMIT_TYPEHASH, to, value, data, deadline, encodeNonce));
    bytes32 eip712DomainHash = domainSeparator();
    callHash = keccak256(abi.encodePacked(uint16(0x1901), eip712DomainHash, hashStruct));
  }

  function executeTypedCallPermit(
    address to,
    uint256 value,
    bytes calldata data,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external payable returns (bytes memory result) {
    require(block.timestamp <= deadline, "!call-permit-expired");
    bytes32 callHash = hashTypedCallPermit(to, value, data, deadline);
    address signer = _recover(callHash, v, r, s);
    require(signer == owner(), "!call-permit-invalid-signature");

    emit CallPermit(signer, to, nonce(), deadline);

    return call(to, value, data);
  }

  function transferERC721(address tokenContract, uint256 tokenId, address to, address signer, uint256 deadline) public {
    require(block.timestamp <= deadline, "!call-permit-expired");
    require(msg.sender == address(this), "!sender-not-authorized");
    require(to != address(0), "!zero-recipient");
    require(to != address(this), "!self-recipient");
    IERC721(tokenContract).safeTransferFrom(address(this), to, tokenId);
    emit TransferERC721Permit(address(this), to, tokenContract, tokenId, deadline, nonce(), signer, msg.sender);
  }

  function transferERC721(
    address tokenContract,
    uint256 tokenId,
    address to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    string memory message = getTransferERC721PermitMessage(tokenContract, tokenId, to, deadline);
    bytes32 signHash = hashPersonalSignedMessage(bytes(message));

    address signer = _recover(signHash, v, r, s);
    require(signer == owner(), "!transfer-permit-invalid-signature");

    _incrementNonce();
    (bool success,) = address(this).call(
      abi.encodeWithSignature(
        "transferERC721(address,uint256,address,address,uint256)", tokenContract, tokenId, to, signer, deadline
      )
    );
    require(success, "ERC721 transfer failed");
  }

  function getTransferERC721PermitMessage(address tokenContract, uint256 tokenId, address to, uint256 deadline)
    public
    view
    returns (string memory)
  {
    return string.concat(
      "I want to transfer ERC721",
      "\n From: ",
      address(this).toHexString(),
      "\n NFT: ",
      tokenContract.toHexString(),
      "\n TokenId: ",
      tokenId.toString(),
      "\n To: ",
      to.toHexString(),
      "\n Before: ",
      deadline.toString(),
      ".",
      "\n Nonce: ",
      nonce().toString(),
      "\n Chain ID: ",
      block.chainid.toString(),
      "\n BY: ",
      name(),
      "\n Version: ",
      "0.0.2"
    );
  }

  function transferERC1155(
    address tokenContract,
    uint256 tokenId,
    uint256 amount,
    address to,
    address signer,
    uint256 deadline
  ) public {
    require(block.timestamp <= deadline, "!call-permit-expired");
    require(msg.sender == address(this), "!sender-not-authorized");
    require(to != address(0), "!zero-recipient");
    require(to != address(this), "!self-recipient");

    IERC1155(tokenContract).safeTransferFrom(address(this), to, tokenId, amount, "");
    emit TransferERC1155Permit(address(this), to, tokenContract, tokenId, amount, deadline, nonce(), signer, msg.sender);
  }

  function transferERC1155(
    address tokenContract,
    uint256 tokenId,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    string memory message = getTransferERC1155PermitMessage(tokenContract, tokenId, amount, to, deadline);
    bytes32 signHash = hashPersonalSignedMessage(bytes(message));

    address signer = ECDSA.recover(signHash, v, r, s);
    require(signer == owner(), "!transfer-permit-invalid-signature");

    _incrementNonce();
    (bool success,) = address(this).call(
      abi.encodeWithSignature(
        "transferERC1155(address,uint256,uint256,address,address,uint256)",
        tokenContract,
        tokenId,
        amount,
        to,
        signer,
        deadline
      )
    );
    require(success, "ERC1155 transfer failed");
  }

  function getTransferERC1155PermitMessage(
    address tokenContract,
    uint256 tokenId,
    uint256 amount,
    address to,
    uint256 deadline
  ) public view returns (string memory) {
    return string.concat(
      "I authorize the transfer of ERC1155 tokens",
      "\n Token Contract: ",
      Strings.toHexString(uint256(uint160(tokenContract)), 20),
      "\n Token ID: ",
      Strings.toString(tokenId),
      "\n Amount: ",
      Strings.toString(amount),
      "\n To: ",
      Strings.toHexString(uint256(uint160(to)), 20),
      "\n Deadline: ",
      Strings.toString(deadline),
      "\n Nonce: ",
      nonce().toString(),
      "\n Chain ID: ",
      block.chainid.toString(),
      "\n BY: ",
      name(),
      "\n Version: ",
      "0.0.2"
    );
  }

  function hashPersonalSignedMessage(bytes memory _msg) public pure returns (bytes32 signHash) {
    signHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", _msg.length.toString(), _msg));
  }

  function transferERC20(address tokenContract, uint256 amount, address to, address signer, uint256 deadline) public {
    require(block.timestamp <= deadline, "!call-permit-expired");
    require(msg.sender == address(this), "!sender-not-authorized");
    require(to != address(0), "!zero-recipient");
    require(to != address(this), "!self-recipient");

    IERC20(tokenContract).transfer(to, amount);
    emit TransferERC20Permit(address(this), to, tokenContract, amount, deadline, nonce(), signer, msg.sender);
  }

  function transferERC20(
    address tokenContract,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    string memory message = getTransferERC20PermitMessage(tokenContract, amount, to, deadline);
    bytes32 signHash = hashPersonalSignedMessage(bytes(message));

    address signer = _recover(signHash, v, r, s);
    require(signer == owner(), "!transfer-permit-invalid-signature");

    _incrementNonce();

    (bool success,) = address(this).call(
      abi.encodeWithSignature(
        "transferERC20(address,uint256,address,address,uint256)", tokenContract, amount, to, signer, deadline
      )
    );
    require(success, "ERC20 transfer failed");
  }

  function getTransferERC20PermitMessage(address tokenContract, uint256 amount, address to, uint256 deadline)
    public
    view
    returns (string memory)
  {
    return string.concat(
      "I authorize the transfer of ERC20 tokens",
      "\n Token Contract: ",
      Strings.toHexString(uint256(uint160(tokenContract)), 20),
      "\n Amount: ",
      Strings.toString(amount),
      "\n To: ",
      Strings.toHexString(uint256(uint160(to)), 20),
      "\n Deadline: ",
      Strings.toString(deadline),
      "\n Nonce: ",
      nonce().toString(),
      "\n Chain ID: ",
      block.chainid.toString(),
      "\n BY: ",
      name(),
      "\n Version: ",
      "0.0.2"
    );
  }

  function transferEther(address payable to, uint256 amount, address signer, uint256 deadline) public {
    require(block.timestamp <= deadline, "!call-permit-expired");
    require(msg.sender == address(this), "!sender-not-authorized");
    require(address(this).balance >= amount, "!insufficient-balance");
    require(to != address(0), "!zero-recipient");
    require(to != address(this), "!self-recipient");
    to.transfer(amount);
    emit TransferEtherPermit(address(this), to, amount, deadline, nonce(), signer, msg.sender);
  }

  function transferEther(address payable to, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
    require(block.timestamp <= deadline, "!call-permit-expired");
    string memory message = getTransferEtherPermitMessage(amount, to, deadline);
    bytes32 signHash = hashPersonalSignedMessage(bytes(message));

    address signer = _recover(signHash, v, r, s);
    require(signer == owner(), "!transfer-permit-invalid-signature");
    _incrementNonce();

    (bool success,) = address(this).call(
      abi.encodeWithSignature("transferEther(address,uint256,address,uint256)", to, amount, signer, deadline)
    );
    require(success, "Ether transfer failed");
  }

  function getTransferEtherPermitMessage(uint256 amount, address to, uint256 deadline)
    public
    view
    returns (string memory)
  {
    return string.concat(
      "I authorize the transfer of Ether",
      "\n Amount: ",
      Strings.toString(amount),
      "\n To: ",
      Strings.toHexString(uint256(uint160(to)), 20),
      "\n Deadline: ",
      Strings.toString(deadline),
      "\n Nonce: ",
      nonce().toString(),
      "\n Chain ID: ",
      block.chainid.toString(),
      "\n BY: ",
      name(),
      "\n Version: ",
      "0.0.2"
    );
  }

  function batchTransfer(bytes[] calldata data, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
    require(block.timestamp <= deadline, "!batch-transfer-permit-expired");
    string memory message = getBatchTransferPermitMessage(data, deadline);
    bytes32 signHash = hashPersonalSignedMessage(bytes(message));

    address signer = ECDSA.recover(signHash, v, r, s);
    require(signer == owner(), "!batch-transfer-permit-invalid-signature");

    _incrementNonce();

    for (uint256 i = 0; i < data.length; i++) {
      (bool success, bytes memory result) = address(this).call(data[i]);
      if (!success) {
        if (result.length > 0) {
          assembly {
            let resultSize := mload(result)
            revert(add(32, result), resultSize)
          }
        } else {
          revert("Batch transfer failed");
        }
      }
    }

    emit BatchTransferPermit(signer, data, deadline, nonce());
  }

  function getBatchTransferPermitMessage(bytes[] calldata data, uint256 deadline) public view returns (string memory) {
    return string(
      abi.encodePacked(
        "I authorize the batch transfer of tokens",
        "\n Deadline: ",
        Strings.toString(deadline),
        "\n Nonce: ",
        Strings.toString(nonce()),
        "\n Chain ID: ",
        Strings.toString(block.chainid),
        "\n BY: ",
        name(),
        "\n Version: ",
        "0.0.3",
        "\n Data: ",
        _bytesArrayToString(data)
      )
    );
  }

  /// @notice Swaps exact amount of tokens using Uniswap V3
  /// @param tokenIn The input token address
  /// @param amountIn The amount of tokens to swap
  /// @param amountOutMinimum The minimum amount of output tokens to receive
  /// @return amountOut The amount of output tokens received
  function swapExactTokensForETH(address tokenIn, uint256 amountIn, uint256 amountOutMinimum)
    internal
    returns (uint256 amountOut)
  {
    require(msg.sender == owner() || msg.sender == address(this), "!not-authorized");

    address router = getUnifiedStore().getAddress("UNISWAP_ROUTER");
    require(router != address(0), "!router-not-found");

    address weth = getUnifiedStore().getAddress("TOKEN_WETH");
    require(weth != address(0), "!weth-not-found");

    // Approve token spend if needed
    IERC20(tokenIn).approve(router, amountIn);

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
      tokenIn: tokenIn,
      tokenOut: weth,
      fee: 500,
      recipient: address(this),
      amountIn: amountIn,
      amountOutMinimum: amountOutMinimum,
      sqrtPriceLimitX96: 0
    });

    amountOut = ISwapRouter(router).exactInputSingle(params);

    // Unwrap WETH to ETH
    IWETH(weth).withdraw(amountOut);
  }

  /// @notice Quotes the expected ETH output for converting a percentage of USDC
  /// @param percent Percentage of USDC to convert (0-100000)
  /// @return expectedOutput The expected amount of ETH to receive
  /// @return amountIn The amount of USDC to be converted
  /// @return amountNoSwap The amount of USDC that will not be swapped
  function quoteUSDCToETH(uint256 percent)
    public
    returns (uint256 expectedOutput, uint256 amountIn, uint256 amountNoSwap)
  {
    require(percent <= 100000, "!invalid-percentage");

    address usdc = getUnifiedStore().getAddress("TOKEN_USDC");
    require(usdc != address(0), "!usdc-not-found");

    address quoter = getUnifiedStore().getAddress("UNISWAP_QUOTER");
    require(quoter != address(0), "!quoter-not-found");

    // Get current USDC balance and decimals
    uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));

    // Calculate amount of USDC to convert based on percentage
    // percent is in basis points (100000 = 100%)
    amountIn = (usdcBalance * percent) / 100000;

    // If no USDC to convert, return 0
    if (amountIn == 0) {
      return (0, 0, usdcBalance);
    }

    address weth = getUnifiedStore().getAddress("TOKEN_WETH");
    require(weth != address(0), "!weth-not-found");

    // Get quote from Uniswap quoter
    (expectedOutput,,,) = IQuoter(quoter).quoteExactInputSingle(
      IQuoter.QuoteExactInputSingleParams({
        tokenIn: usdc,
        tokenOut: weth,
        amountIn: amountIn,
        fee: 500,
        sqrtPriceLimitX96: 0
      })
    );

    amountNoSwap = usdcBalance - amountIn;
  }

  /// @notice Converts a percentage of USDC to ETH and sends both to recipient
  /// @param percent Percentage of USDC to convert (0-100000)
  /// @param recipient Address to receive both USDC and ETH
  function convertUSDCToETHAndSend(uint256 percent, uint256 minAmountOut, address recipient) public {
    require(msg.sender == owner() || msg.sender == address(this), "!not-authorized");
    require(percent <= 100000, "!invalid-percentage");
    require(recipient != address(0), "!invalid-recipient");

    address usdc = getUnifiedStore().getAddress("TOKEN_USDC");
    require(usdc != address(0), "!usdc-not-found");

    uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
    if (usdcBalance == 0) {
      return;
    }

    uint256 amountToConvert = (usdcBalance * percent) / 100000;
    swapExactTokensForETH(usdc, amountToConvert, minAmountOut);

    // Send remaining USDC to recipient
    uint256 remainingUSDC = IERC20(usdc).balanceOf(address(this));
    if (remainingUSDC > 0) {
      bool success = IERC20(usdc).transfer(recipient, remainingUSDC);
      require(success, "!usdc-transfer-failed");
    }

    // Send ETH to recipient
    uint256 ethBalance = address(this).balance;
    if (ethBalance > 0) {
      (bool success,) = recipient.call{ value: ethBalance }("");
      require(success, "!eth-transfer-failed");
    }
  }

  function convertUSDCToETHAndSend(
    uint256 percent,
    uint256 minAmountOut,
    address recipient,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(percent <= 100000, "!invalid-percentage");
    string memory message = getConvertUSDCToETHAndSendPermitMessage(percent, minAmountOut, recipient, deadline);
    bytes32 signHash = hashPersonalSignedMessage(bytes(message));

    address signer = _recover(signHash, v, r, s);
    require(signer == owner(), "!transfer-permit-invalid-signature");

    _incrementNonce();
    (bool success, bytes memory returnData) = address(this).call(
      abi.encodeWithSignature("convertUSDCToETHAndSend(uint256,uint256,address)", percent, minAmountOut, recipient)
    );
    if (!success) {
      if (returnData.length > 0) {
        assembly {
          let returnDataSize := mload(returnData)
          revert(add(32, returnData), returnDataSize)
        }
      } else {
        revert("!convert-usdc-to-eth-and-send-failed");
      }
    }
  }

  function getConvertUSDCToETHAndSendPermitMessage(
    uint256 percent,
    uint256 minAmountOut,
    address recipient,
    uint256 deadline
  ) public view returns (string memory) {
    return string.concat(
      "I authorize the conversion of USDC to ETH",
      "\n Percent: ",
      Strings.toString(percent),
      "\n Min Amount Out: ",
      Strings.toString(minAmountOut),
      "\n Recipient: ",
      Strings.toHexString(uint256(uint160(recipient)), 20),
      "\n Deadline: ",
      Strings.toString(deadline),
      "\n Nonce: ",
      nonce().toString(),
      "\n Chain ID: ",
      block.chainid.toString(),
      "\n BY: ",
      name(),
      "\n Version: ",
      "0.0.2"
    );
  }
}
