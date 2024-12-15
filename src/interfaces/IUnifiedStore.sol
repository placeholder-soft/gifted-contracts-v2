// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUnifiedStore {
    function getAddress(string calldata key) external view returns (address);
}
