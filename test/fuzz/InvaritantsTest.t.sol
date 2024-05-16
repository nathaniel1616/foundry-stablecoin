// what are the invariants?
// - the sum of the balances of all accounts should be equal to the total supply of DSC
// - sum of collateral balances should be greeter than the DSC supply or minted DSC
// - the getter view functions should return the same value as the state variables and never revert

//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";
import {ERC20Mock} from "../mock/MockERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract InvariantsTest is StdInvariant, Test {
    DecentralizedStableCoin decentralizedStableCoin;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    DeployDecentralizedStableCoin deployDecentralizedStableCoin;
    Handler handler;

    address USER = makeAddr("USER");
    address weth;
    address wbtc;
    address ethUSDPriceFeed;
    address btcUsdPriceFeed;

    uint256 constant STARTING_AMOUNT = 1e30;
    uint256 private constant PRICE_PRECISION_CHAINLINK = 1e10;
    uint256 private constant PRECISION = 1e18;

    function setUp() external {
        deployDecentralizedStableCoin = new DeployDecentralizedStableCoin();
        (decentralizedStableCoin, dscEngine, helperConfig) = deployDecentralizedStableCoin.run();
        (weth, wbtc, ethUSDPriceFeed, btcUsdPriceFeed,) = helperConfig.activateNetworkConfig();
        handler = new Handler(dscEngine, decentralizedStableCoin);
        targetContract(address(handler));
    }
    // invariant test

    function invariant_HandlerprotocolMustHaveMoreCollateralThanDSCSupply() public view {
        uint256 dscSupply = decentralizedStableCoin.totalSupply();

        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
        //  get the total collateral deposited in USD
        uint256 totalCollateralInUsd =
            getAmountInUSD(ethUSDPriceFeed, totalWethDeposited) + getAmountInUSD(btcUsdPriceFeed, totalWbtcDeposited);

        console.log("totalCollateral: ", totalCollateralInUsd);
        console.log("dscSupply: ", dscSupply);
        console.log("Number of Redeems", handler.NumOfRedeems());
        console.log("Number of Mints", handler.NumOfMints());

        console.log("Number of Deposits", handler.NumOfDeposits());

        assert(totalCollateralInUsd >= dscSupply);
    }

    // getters function should never revert
    function invariant_getterShouldNeverRevert() public view {
        decentralizedStableCoin.totalSupply();
        // getter function for DSCEngine

        dscEngine.getMinimumHealthFactor();
        dscEngine.getTokenaddress(0);
        dscEngine.getTokenaddress(1);
        dscEngine.getLiquidationPrecision();
        dscEngine.getLiquidationBonus();
        dscEngine.getLiquidationThreshold();
        dscEngine.getPricePrecisionChainlink();
        dscEngine.getPrecision();
    }

    function invariant_otherGetterFunctionsShouldNeverRevert() public hasDepositedCollatoral(USER) {
        dscEngine.getTokenAmountFromUsd(weth, 1000);
        dscEngine.getTokenAmountFromUsd(wbtc, 1000);
        dscEngine.getAccountInformation(USER);
        dscEngine.getHealthFactor(USER);
        dscEngine.getHealthFactor(USER);
        dscEngine.getAccountCollateralValueInUsd(USER);
        dscEngine.getCollateralDeposited(weth, USER);
    }

    modifier hasDepositedCollatoral(address _user) {
        ERC20Mock(weth).mint(_user, STARTING_AMOUNT);
        ERC20Mock(wbtc).mint(_user, STARTING_AMOUNT);
        vm.startPrank(_user);
        IERC20(weth).approve(address(dscEngine), STARTING_AMOUNT);
        dscEngine.depositCollateral(weth, STARTING_AMOUNT);

        IERC20(wbtc).approve(address(dscEngine), STARTING_AMOUNT);
        dscEngine.depositCollateral(wbtc, STARTING_AMOUNT);

        vm.stopPrank();

        console.log("WETH and WBTC minted to this address", _user);
        _;
    }

    // function invariant_HandlerUserCanRedeemCollatoral() public {
    //     uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
    //     uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
    //     uint256 totalCollateral = totalWethDeposited + totalWbtcDeposited;

    //     uint256 dscSupply = decentralizedStableCoin.totalSupply();

    //     console.log("totalCollateral: ", totalCollateral);
    //     console.log("dscSupply: ", dscSupply);

    //     assert(totalCollateral >= dscSupply);
    // }

    // helper functions

    // getAmountInUSD
    function getAmountInUSD(address _tokenPriceFeed, uint256 _amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_tokenPriceFeed);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (_amount * (uint256(price) * PRICE_PRECISION_CHAINLINK) / PRECISION);
    }
}
