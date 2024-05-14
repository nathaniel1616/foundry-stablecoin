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

    int256 public constant BTC_PRICE_USD = 600000e8; // $60,000U
    int256 public constant ETH_PRICE_USD = 3000e8; // $ 3,000
    uint8 public constant CHAIN_LINK_PRICE_DECIMALS_DEFAULT = 8;
    uint256 constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function setUp() public {
        helperConfig = new HelperConfig();
        (s_weth, s_wbtc, s_ethUSDPriceFeed, s_btcUsdPriceFeed,) = helperConfig.activateNetworkConfig();
    }

    function test_GetSepoliaConfig() public view {
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getSepoliaConfig();
        assertEq(networkConfig.weth, 0xD341D0f0Ad5d9dB4Cf5dC9929743d8F761Ec6418);
        assertEq(networkConfig.wbtc, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        assertEq(networkConfig.ethUSDPriceFeed, 0x694AA1769357215DE4FAC081bf1f309aDC325306);
        assertEq(networkConfig.btcUsdPriceFeed, 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
    }

    function test_GetOrCreateAnvilConfig() public {
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getOrCreateAnvilConfig();
        assertEq(networkConfig.weth, s_weth);
        assertEq(networkConfig.wbtc, s_wbtc);
        assertEq(networkConfig.ethUSDPriceFeed, s_ethUSDPriceFeed);
        assertEq(networkConfig.btcUsdPriceFeed, s_btcUsdPriceFeed);
        assertEq(networkConfig.deployer, 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
    }

    // constructor test
    // helperConfig changes with different chainid
    function test_ConfigChangesOnDiffererentChainId() public {
        // chainid 11155111
        vm.chainId(11155111);
        // print chainID
        console.log("Starting ChainID: ", block.chainid);
        HelperConfig helperConfig2 = new HelperConfig();
        (address weth, address wbtc, address ethUSDPriceFeed, address btcUsdPriceFeed,) =
            helperConfig2.activateNetworkConfig();
        assertEq(weth, 0xD341D0f0Ad5d9dB4Cf5dC9929743d8F761Ec6418);
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
        (weth, wbtc, ethUSDPriceFeed, btcUsdPriceFeed,) = helperConfig.activateNetworkConfig();
        assertEq(weth, s_weth);
        assertEq(wbtc, s_wbtc);
        assertEq(ethUSDPriceFeed, s_ethUSDPriceFeed);
        assertEq(btcUsdPriceFeed, s_btcUsdPriceFeed);
    }

    function testConfigConstants() public view {
        assertEq(helperConfig.BTC_PRICE_USD(), BTC_PRICE_USD);
        assertEq(helperConfig.ETH_PRICE_USD(), ETH_PRICE_USD);
        assertEq(helperConfig.CHAIN_LINK_PRICE_DECIMALS_DEFAULT(), CHAIN_LINK_PRICE_DECIMALS_DEFAULT);
    }
}
