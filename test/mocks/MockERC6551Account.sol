// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "../../src/erc6551/interfaces/IERC6551Account.sol";

import { console } from "forge-std/console.sol";
contract MockERC6551Account is IERC165, IERC6551Account {
    uint256 public state;
    bool private _initialized;
    uint256 public _chainId;
    address public _tokenContract;
    uint256 public _tokenId;

    event Initialized(bool val, uint256 chainId, address tokenContract, uint256 tokenId);

    receive() external payable {}

    function initialize(bool val, uint256 chainId, address tokenContract, uint256 tokenId) external {
        if (!val) {
            revert("disabled");
        }
        _initialized = val;
        _chainId = chainId;
        _tokenContract = tokenContract;
        _tokenId = tokenId;
        console.log("initialized", chainId, tokenContract, tokenId);
        emit Initialized(val, chainId, tokenContract, tokenId);
    }

    function executeCall(address, uint256, bytes calldata)
        external
        payable
        returns (bytes memory)
    {
        revert("disabled");
    }

    function token() external view returns (uint256, address, uint256) {
        return (_chainId, _tokenContract, _tokenId);
    }

    function salt() external pure returns (bytes32) {
        return bytes32(0);
    }

    function owner() public pure returns (address) {
        revert("disabled");
    }

    function nonce() external pure returns (uint256) {
        return 0;
    }

    function isValidSigner(address, bytes calldata) public pure returns (bytes4) {
        revert("disabled");
    }

    function supportsInterface(bytes4 interfaceId) public view returns (bool) {
        if (interfaceId == 0xffffffff) return false;
        return _initialized;
    }
}
