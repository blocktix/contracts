pragma solidity ^0.4.11;


/**
 * @title Stalled ERC20 token
 */
contract TIXStalledToken {
  uint256 public totalSupply;
  bool public isFinalized; // switched to true in operational state
  address public ethFundDeposit; // deposit address for ETH for Blocktix

  function balanceOf(address who) constant returns (uint256);
}
