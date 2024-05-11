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

    /**
     * @notice deploy the decentralized stable coin
     * @return DecentralizedStableCoin The contract of the decentralized stable coin
     * @return DSC Engine The contract of the DSC Engine. Which is the main contract that will be used to interact with the decentralized stable coin
     * @return HelperConfig The contract of the HelperConfig. This contract is used to get the configuration of the network.
     */
    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        helperConfig = new HelperConfig();
        (weth, wbtc, ethUSDPriceFeed, btcUsdPriceFeed, deployer) = helperConfig.activateNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [ethUSDPriceFeed, btcUsdPriceFeed];

        vm.startBroadcast();
        decentralizedStableCoin = new DecentralizedStableCoin();
        dSCEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(decentralizedStableCoin));
        decentralizedStableCoin.transferOwnership(address(dSCEngine));
        vm.stopBroadcast();
        return (decentralizedStableCoin, dSCEngine, helperConfig);
    }
}
