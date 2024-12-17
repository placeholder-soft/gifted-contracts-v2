// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IGasSponsorBook.sol";
import "../interfaces/IVault.sol";

contract MockGasSponsorBook is IGasSponsorBook {
  IVault private _vault;
  uint256 private _feePerSponsorTicket;
  mapping(uint256 => uint256) private _sponsorTickets;

  function setVault(IVault vault) external {
    _vault = vault;
  }

  function setFeePerSponsorTicket(uint256 feePerSponsorTicket_) external {
    _feePerSponsorTicket = feePerSponsorTicket_;
  }

  function addSponsorTicket(uint256 ticket) external payable {
    _sponsorTickets[ticket] = msg.value;
  }

  function consumeSponsorTicket(uint256 ticket, address) external {
    _sponsorTickets[ticket] = 0;
  }

  function feePerSponsorTicket() external view returns (uint256) {
    return _feePerSponsorTicket;
  }

  function sponsorTickets(uint256 ticket) external view returns (uint256) {
    return _sponsorTickets[ticket];
  }
}
