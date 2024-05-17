// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title OracleLib
 * @notice OracleLib is a library for handling oracle related functions .
 * @notice this is to check if the oracle has properly updated the price or not
 */
library OracleLib {
    error OracleLib__PriceIsTooOld();

    uint256 private constant TIME_LIMIT = 2 hours;
    /**
     * @notice stalePrice is a function to check if the price is stale or not
     * @param priceFeed is the address of the price feed
     */

    function stalePrice(AggregatorV3Interface priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();
        uint256 lastTimeUpdate = block.timestamp - updatedAt;
        if (lastTimeUpdate > TIME_LIMIT) {
            revert OracleLib__PriceIsTooOld();
        }
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
