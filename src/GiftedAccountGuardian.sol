// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/access/Ownable2Step.sol";
import "@openzeppelin/utils/Address.sol";
import "./interfaces/IGiftedAccountGuardian.sol";
import "./interfaces/IGiftedAccount.sol";

contract GiftedAccountGuardian is Ownable2Step, IGiftedAccountGuardian {
    mapping(address => bool) private _isExecutor;
    address private _implementation;

    constructor() Ownable(msg.sender) {}

    function setExecutor(address executor, bool trusted) external onlyOwner {
        _isExecutor[executor] = trusted;
        emit ExecutorUpdated(executor, trusted);
    }

    // @dev set new implementation address
    // note that we don't call any upgrade initialization function
    // which leave it to the owner to call it
    function setGiftedAccountImplementation(address newImplementation) external onlyOwner {
        require(newImplementation.code.length > 0, "!newImplementation-is-not-a-contract");
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }

    function getImplementation() external view returns (address) {
        return _implementation;
    }

    function isExecutor(address executor) external view returns (bool) {
        if (_isExecutor[executor]) return true;
        if (executor == owner()) return true;
        return false;
    }
}
