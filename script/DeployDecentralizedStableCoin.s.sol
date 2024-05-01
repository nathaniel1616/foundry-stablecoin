// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract DeployDecentralizedStableCoin is Script {
    DecentralizedStableCoin decentralizedStableCoin;
    DSCEngine dSCEngine;
    HelperConfig public helperConfig;

    address public weth;
    address public wbtc;
    address public ethUSDPriceFeed;
    address public btcUsdPriceFeed;
    uint256 public deployer;

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine) {
        helperConfig = new HelperConfig();
        (weth, wbtc, ethUSDPriceFeed, btcUsdPriceFeed, deployer) = helperConfig.activateNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [ethUSDPriceFeed, btcUsdPriceFeed];

        vm.startBroadcast();
        decentralizedStableCoin = new DecentralizedStableCoin();
        dSCEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(decentralizedStableCoin));
        decentralizedStableCoin.transferOwnership(address(dSCEngine));
        vm.stopBroadcast();
        return (decentralizedStableCoin, dSCEngine);
    }
}
