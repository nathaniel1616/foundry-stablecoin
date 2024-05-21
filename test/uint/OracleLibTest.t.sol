// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Test, console} from "forge-std/Test.sol";
import {OracleLib} from "../../src/OracleLib.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

/**
 * @title OracleLibTest
 * @notice OracleLib is a library for handling oracle related functions .
 * @notice this is to check if the oracle has properly updated the price or not
 */
contract OracleTest is Test {
    using OracleLib for AggregatorV3Interface;

    int256 public constant ETH_PRICE_USD = 3000e8; // $ 3,000
    uint8 public constant CHAIN_LINK_PRICE_DECIMALS_DEFAULT = 8;
    AggregatorV3Interface public ethUsdPriceFeed;

    uint80 public roundId;
    int256 public answer;
    uint256 public startedAt;
    uint256 public updatedAt;
    uint80 public answeredInRound;

    function setUp() external {
        ethUsdPriceFeed = new MockV3Aggregator(CHAIN_LINK_PRICE_DECIMALS_DEFAULT, ETH_PRICE_USD);
        (roundId, answer, startedAt, updatedAt, answeredInRound) = ethUsdPriceFeed.stalePrice();
    }

    function testGetLatestPrice() public view {
        assertEq(answer, ETH_PRICE_USD);
    }

    function testRevertsIfPriceIsStale() public {
        uint256 timePassed = block.timestamp + 3 hours;
        // vm.roll(100);
        vm.warp(timePassed);
        int256 newAnswer;
        vm.expectRevert(OracleLib.OracleLib__PriceIsTooOld.selector);
        (roundId, newAnswer, startedAt, updatedAt, answeredInRound) = ethUsdPriceFeed.stalePrice();
    }

    function testOracleDoesNotRevertWhenUpdates() public {
        uint256 timePassed = block.timestamp + 3 hours;
        vm.warp(timePassed);
        int256 newAnswer;
        MockV3Aggregator(address(ethUsdPriceFeed)).updateAnswer(5000e8);
        (roundId, newAnswer, startedAt, updatedAt, answeredInRound) = ethUsdPriceFeed.stalePrice();
        console.log("updated at timestamp: ", updatedAt);
        assertEq(updatedAt, timePassed);
        assertEq(newAnswer, 5000e8);
    }
}
