// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
struct GiftingRecord {
    address sender;
    address recipient;
}

interface IGiftedBox {
    function getGiftingRecord(
        uint256 tokenId
    ) external view returns (GiftingRecord memory);
}
