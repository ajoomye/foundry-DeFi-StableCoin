//SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


/**
    * @title OracleLib
    * @author Abdurraheem Joomye
    * @notice This library is used to check Chainlink Oracle for stale data.
    * If Chainlink Network breaks, we are screwed.
 */

library OracleLib {

    error OracleLib__StaleData();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestPrice(AggregatorV3Interface _priceFeed) public view 
    returns (uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId, int256 answer, 
        uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
        _priceFeed.latestRoundData();

        uint256 timeElapsed = block.timestamp - updatedAt;
        if (timeElapsed > TIMEOUT) {
            revert OracleLib__StaleData();
        }   

        return (roundId, answer, startedAt, updatedAt, answeredInRound);

    }

}