// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
struct GiftingRecord {
    // embedded address of the gift sender
    address sender;
    // recipient of the gift
    address recipient;
    // external wallet address
    address operator;
}

enum GiftingRole {
    SENDER,
    RECIPIENT,
    OPERATOR
}

interface IGiftedBox {
    function getGiftingRecord(
        uint256 tokenId
    ) external view returns (GiftingRecord memory);

    function tokenAccountAddress(
        uint256 tokenId
    ) external view returns (address);

    function sendGift(address sender, address recipient) external payable;

    function claimGift(uint256 tokenId, GiftingRole role) external;

    function claimGiftByClaimer(uint256 tokenId, GiftingRole role) external;

    function transferERC721PermitMessage(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        address to,
        uint256 deadline
    ) external view returns (string memory);

    function transferERC721(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function transferERC1155PermitMessage(
        uint256 giftedBoxTokenId,
        address tokenContract,
        uint256 tokenId,
        uint256 amount,
        address to,
        uint256 deadline
    ) external view returns (string memory);

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
    ) external;
}
