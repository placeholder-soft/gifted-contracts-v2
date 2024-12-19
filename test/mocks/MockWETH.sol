// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "../../src/interfaces/IWETH.sol";

contract MockWETH is ERC20, IWETH {
  constructor() ERC20("Wrapped Ether", "WETH") { }

  function deposit() public payable override {
    _mint(msg.sender, msg.value);
  }

  function withdraw(uint256 amount) external override {
    require(balanceOf(msg.sender) >= amount, "MockWETH: insufficient balance");
    _burn(msg.sender, amount);
    (bool success,) = msg.sender.call{ value: amount }("");
    require(success, "MockWETH: ETH transfer failed");
  }

  receive() external payable {
    deposit();
  }
}
