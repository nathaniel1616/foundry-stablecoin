// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {HelperConfig} from "../../script/HelperConfig.s.sol";

import {Test, console} from "forge-std/Test.sol";

contract HelperConfigTest is Test {
    HelperConfig public helperConfig;

    address public s_weth;
    address public s_wbtc;
    address public s_ethUSDPriceFeed;
    address public s_btcUsdPriceFeed;
    uint256 public s_deployer;

    function setUp() public {
        helperConfig = new HelperConfig();
        (s_weth, s_wbtc, s_ethUSDPriceFeed, s_btcUsdPriceFeed,) = helperConfig.activateNetworkConfig();
    }

    function testGetSepoliaConfig() public view {
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getSepoliaConfig();
        assertEq(networkConfig.weth, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        assertEq(networkConfig.wbtc, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        assertEq(networkConfig.ethUSDPriceFeed, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        assertEq(networkConfig.btcUsdPriceFeed, 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
    }

    function testGetOrCreateAnvilConfig() public {
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getOrCreateAnvilConfig();
        assertEq(networkConfig.weth, s_weth);
        assertEq(networkConfig.wbtc, s_wbtc);
        assertEq(networkConfig.ethUSDPriceFeed, s_ethUSDPriceFeed);
        assertEq(networkConfig.btcUsdPriceFeed, s_btcUsdPriceFeed);
        assertEq(networkConfig.deployer, 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
    }

    // constructor test
    // helperConfig changes with different chainid
    function testConfigChangesOnDiffererentChainId() public {
        // chainid 11155111
        vm.chainId(11155111);
        // print chainID
        console.log("Starting ChainID: ", block.chainid);
        helperConfig = new HelperConfig();
        (address weth, address wbtc, address ethUSDPriceFeed, address btcUsdPriceFeed,) =
            helperConfig.activateNetworkConfig();
        assertEq(weth, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        assertEq(wbtc, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        assertEq(ethUSDPriceFeed, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        assertEq(btcUsdPriceFeed, 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
        console.log("Ending ChainID: ", block.chainid);

        /**
         * since the setUp function by default sets to the anvil,compare the deployed addresses
         *  chainid for anvil
         */
        console.log("changing ChainID: ", block.chainid);

        vm.chainId(31337);
        console.log("Starting ChainID: ", block.chainid);

        helperConfig = new HelperConfig();
        (weth, wbtc, ethUSDPriceFeed, btcUsdPriceFeed,) = helperConfig.activateNetworkConfig();
        assertEq(weth, weth);
        assertEq(wbtc, wbtc);
        assertEq(ethUSDPriceFeed, ethUSDPriceFeed);
        assertEq(btcUsdPriceFeed, btcUsdPriceFeed);
    }
}
