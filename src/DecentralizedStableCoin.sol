//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

/**
 * @title DecentralizedStableCoin
 * @author Abdurraheem Joomye
 * @dev A contract for a StableCoin using Solidity
 * @notice This contract is for a StableCoin that is decentralized and anchored to the value of the US Dollar
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * This contract is meant to be governed by DSCEngine. This is just the ERC20 implementation of the stablecoin.
 * Uses OpenZeppelin's ERC20 contract as a base
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__MustbeMorethanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable() {
    
    }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustbeMorethanZero();
        }
        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert DecentralizedStableCoin__MustbeMorethanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
