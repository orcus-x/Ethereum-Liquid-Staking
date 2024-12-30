// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VETHTokenContract is ERC20, Ownable {
    // Constructor to initialize the token with a name, symbol, and decimals
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    // Function to mint new tokens, only the owner (the staking contract) can call this
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Function to burn tokens, only the owner (the staking contract) can call this
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
