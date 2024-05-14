// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mock/MockERC20.sol";

contract HelperConfig is Script {
    int256 public constant BTC_PRICE_USD = 600000e8; // $60,000U
    int256 public constant ETH_PRICE_USD = 3000e8; // $ 3,000
    uint8 public constant CHAIN_LINK_PRICE_DECIMALS_DEFAULT = 8;
    uint256 constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    address weth;
    address wbtc;

    struct NetworkConfig {
        address weth;
        address wbtc;
        address ethUSDPriceFeed;
        address btcUsdPriceFeed;
        uint256 deployer;
    }

    NetworkConfig public activateNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activateNetworkConfig = getSepoliaConfig();
        } else {
            activateNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            weth: 0xD341D0f0Ad5d9dB4Cf5dC9929743d8F761Ec6418,
            wbtc: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            ethUSDPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            btcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployer: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activateNetworkConfig.wbtc != address(0)) {
            return activateNetworkConfig;
        } else {
            vm.startBroadcast();
            ERC20Mock weth_contract = new ERC20Mock("WETH", "WETH");
            ERC20Mock wbtc_contract = new ERC20Mock("WBTC", "WBTC");
            MockV3Aggregator ethToUsdPriceFeed = new MockV3Aggregator(CHAIN_LINK_PRICE_DECIMALS_DEFAULT, ETH_PRICE_USD);
            MockV3Aggregator btctoUsdPriceFeed = new MockV3Aggregator(CHAIN_LINK_PRICE_DECIMALS_DEFAULT, BTC_PRICE_USD);
            vm.stopBroadcast();
            weth = address(weth_contract);
            wbtc = address(wbtc_contract);
            return NetworkConfig({
                weth: weth,
                wbtc: wbtc,
                ethUSDPriceFeed: address(ethToUsdPriceFeed),
                btcUsdPriceFeed: address(btctoUsdPriceFeed),
                deployer: DEFAULT_ANVIL_PRIVATE_KEY
            });
        }
    }
}
