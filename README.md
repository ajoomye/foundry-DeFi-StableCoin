# Decentralized StableCoin (DSC) Project

This repository contains the smart contract implementation of a **Decentralized StableCoin (DSC)** system, which is pegged to the US Dollar and collateralized by Ethereum (ETH) and Bitcoin (BTC). The project leverages **Foundry** for testing and deployment, ensuring a robust and scalable implementation.

**NOTE: THE TESTS ARE NOT COMPLETE**

---

## Overview

The DSC system is designed to provide a decentralized and algorithmic stablecoin solution with the following features:

- **Collateralized by ETH and BTC**: The stablecoin's value is secured using ETH and BTC as collateral.
- **Algorithmic Minting**: DSC tokens are minted algorithmically to maintain the peg to USD.
- **Decentralized Governance**: The system is governed by a `DSEngine` contract to ensure decentralization.
- **Overcollateralization**: Users must deposit collateral exceeding the value of minted DSC to ensure system stability.

---

## Smart Contracts

### 1. DecentralizedStableCoin.sol
- An ERC20 token with additional burn and mint functionalities.
- Key Features:
  - **Minting**: Only the owner (governance) can mint new DSC tokens.
  - **Burning**: DSC tokens can be burned to reduce supply.
  - Implements OpenZeppelin's ERC20Burnable and Ownable.

### 2. DSCEngine.sol
- The core logic contract for managing collateral, minting, and liquidation.
- Key Features:
  - Deposit and redeem collateral (ETH, BTC).
  - Mint and burn DSC tokens based on the health factor of user accounts.
  - Liquidation mechanism to ensure overcollateralization.
  - Price feeds via Chainlink for collateral valuation.

---

## Key Concepts

1. **Health Factor**: A metric to determine the safety of a user's collateralized position. A value below `1` triggers liquidation.
2. **Collateralization**: The system requires users to deposit more collateral than the DSC they mint.
3. **Liquidation**: Users with a health factor below `1` can have their collateral seized to cover their debt.

---

