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
}
