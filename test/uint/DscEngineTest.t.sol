// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../mock/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DscEngineTest is Test {
    DeployDecentralizedStableCoin public deployDecentralizedStableCoin;
    DecentralizedStableCoin public decentralizedStableCoin;
    DSCEngine dSCEngine;

    HelperConfig helperConfig;

    address weth;
    address wbtc;
    address ethUSDPriceFeed;
    address btcUsdPriceFeed;
    uint256 deployer;

    address USER = makeAddr("user");
    address USER_2 = makeAddr("user2");

    uint256 private constant PRICE_PRECISION_CHAINLINK = 1e10;
    uint256 private constant PRECISION = 1e18;

    uint256 constant STARTING_AMOUNT = 5e30;
    uint256 constant AMOUNT_DEPOSITED = 3e18;
    int256 constant BTC_PRICE_USD = 60000; // $60,000U
    int256 constant ETH_PRICE_USD = 3000; // $ 3,000

    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    function setUp() external {
        deployDecentralizedStableCoin = new DeployDecentralizedStableCoin();
        (decentralizedStableCoin, dSCEngine, helperConfig) = deployDecentralizedStableCoin.run();
        (weth, wbtc, ethUSDPriceFeed, btcUsdPriceFeed, deployer) = helperConfig.activateNetworkConfig();
    }

    function test_dscEngineisOwnerofDscStablecoin() public view {
        assertEq(decentralizedStableCoin.owner(), address(dSCEngine));
    }

    function test_wethBTCIsDeployed() public view {
        assert(dSCEngine.getTokenaddress(0) != address(0));
        assertEq(dSCEngine.getTokenaddress(0), weth);
    }

    // units test for depositCollateral function
    function test_depositCollateralRevertsWhenAmountIsZero() public {
        address weth_tokenAddress = dSCEngine.getTokenaddress(0);
        hoax(USER);
        vm.expectRevert(DSCEngine.DSCEngine__ShouldBeMoreThanZero.selector);
        dSCEngine.depositCollateral(weth_tokenAddress, 0);
    }

    // minting weth, and wbtc tokens
    modifier userHasWethAndWBTC() {
        ERC20Mock(weth).mint(USER, STARTING_AMOUNT);
        ERC20Mock(wbtc).mint(USER, STARTING_AMOUNT);

        console.log("WBTC and WETH minted to this address", USER);
        _;
    }

    modifier hasDepositedCollatoral(address _user) {
        ERC20Mock(weth).mint(_user, STARTING_AMOUNT);
        ERC20Mock(wbtc).mint(_user, STARTING_AMOUNT);
        vm.startPrank(_user);
        IERC20(weth).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        dSCEngine.depositCollateral(weth, AMOUNT_DEPOSITED);

        // IERC20(wbtc).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        // dSCEngine.depositCollateral(wbtc, AMOUNT_DEPOSITED);

        vm.stopPrank();

        console.log("WETH minted to this address", _user);
        _;
    }

    function test_depositCollateralRevertsWhenTOkenIsNotAllowed() public {
        ERC20Mock fakeToken = new ERC20Mock("FakeToken", "FK");
        fakeToken.mint(USER, STARTING_AMOUNT);

        console.log("Fake token has been minted ");
        hoax(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dSCEngine.depositCollateral(address(fakeToken), AMOUNT_DEPOSITED);
    }

    function test_depositCollateralAddsUserCollateralDeposited() public userHasWethAndWBTC {
        vm.startPrank(USER);
        IERC20(weth).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        dSCEngine.depositCollateral(weth, AMOUNT_DEPOSITED);

        vm.stopPrank();

        assertEq(dSCEngine.getCollateralDeposited(USER, weth), AMOUNT_DEPOSITED);
    }

    function test_depositCollateralEmitsCollateralEvent() public userHasWethAndWBTC {
        vm.startPrank(USER);
        IERC20(weth).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        vm.expectEmit(true, true, true, false, address(dSCEngine));
        emit CollateralDeposited(USER, weth, AMOUNT_DEPOSITED);
        dSCEngine.depositCollateral(weth, AMOUNT_DEPOSITED);
        vm.stopPrank();
    }

    function test_depositCollateralTransferTokenToDSCEngine() public userHasWethAndWBTC {
        uint256 startingUserWethBalance = IERC20(weth).balanceOf(USER);
        uint256 startingDSCEngineWethBalance = IERC20(weth).balanceOf(address(dSCEngine));

        vm.startPrank(USER);
        IERC20(weth).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        dSCEngine.depositCollateral(weth, AMOUNT_DEPOSITED);
        vm.stopPrank();
        uint256 endingUserWethBalance = IERC20(weth).balanceOf(USER);
        uint256 endingDSCEngineWethBalance = IERC20(weth).balanceOf(address(dSCEngine));
        uint256 expectedEndingUserWethBalance = startingUserWethBalance - AMOUNT_DEPOSITED;
        uint256 expectedEndingDSCEngineWethBalance = startingDSCEngineWethBalance + AMOUNT_DEPOSITED;
        assertEq(endingUserWethBalance, expectedEndingUserWethBalance);
        assertEq(endingDSCEngineWethBalance, expectedEndingDSCEngineWethBalance);
    }

    //depositCollateralAndMintDSC
    function test_depositCollateralAndMintDSCInSingleTransaction() public userHasWethAndWBTC {
        // arrange , act , assert
        uint256 startingUserDSCBalance = dSCEngine.getDscMintedBy(USER);
        vm.startPrank(USER);
        IERC20(weth).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        dSCEngine.depositCollateralAndMintDSC(weth, AMOUNT_DEPOSITED, AMOUNT_DEPOSITED);
        vm.stopPrank();

        uint256 endingUserDSCBalance = dSCEngine.getDscMintedBy(USER);
        console.log("user health factor: ", dSCEngine.getHealthFactor(USER));
        console.log("user collateral value: ", dSCEngine.getAccountCollateralValueInUsd(USER));
        assertEq(startingUserDSCBalance, 0);
        assertEq(endingUserDSCBalance, AMOUNT_DEPOSITED);
    }

    // cannot deposit and mint all the colatoral value
    function test_depositCollateralAndMintDSCRevertsWhenUserTriesToMintAllCollateral() public userHasWethAndWBTC {
        vm.startPrank(USER);
        IERC20(weth).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        console.log("Starting  Weth Balance of User: ", IERC20(weth).balanceOf(USER));
        console.log("starting user health factor: ", dSCEngine.getHealthFactor(USER));

        uint256 userCollateralValue = dSCEngine.getAccountCollateralValueInUsd(USER);
        // vm.expectRevert();

        //depositing collateral
        dSCEngine.depositCollateral(weth, AMOUNT_DEPOSITED);
        console.log("user health factor after deposited collatoral: ", dSCEngine.getHealthFactor(USER));
        console.log("user collateral value: ", dSCEngine.getAccountCollateralValueInUsd(USER));

        // minting DSC
        dSCEngine.mintDSC(dSCEngine.getCollateralDeposited(USER, weth));
        console.log("after minting");
        console.log("user health factor: ", dSCEngine.getHealthFactor(USER));
        console.log("user collateral deposited: ", dSCEngine.getCollateralDeposited(USER, weth));
        console.log("DsC minted by user", dSCEngine.getDscMintedBy(USER));
        console.log("Weth deposited by user", dSCEngine.getCollateralDeposited(USER, weth));
        console.log("Ending Weth Balance of User: ", IERC20(weth).balanceOf(USER));

        vm.stopPrank();
    }

    // function test_depositCollateralAndGetAccountInfo() public userHasWethAndWBTC {
    //     uint256 startingUserWethBalance = IERC20(weth).balanceOf(USER);
    //     uint256 startingDSCEngineWethBalance = IERC20(weth).balanceOf(address(dSCEngine));

    //     vm.startPrank(USER);
    //     IERC20(weth).approve(address(dSCEngine), AMOUNT_DEPOSITED);
    //     dSCEngine.depositCollateral(weth, AMOUNT_DEPOSITED);
    //     vm.stopPrank();
    // }

    // minting

    function test_mintDSCRevertsWhenAmountIsZero() public hasDepositedCollatoral(USER) {
        hoax(USER);
        vm.expectRevert(DSCEngine.DSCEngine__ShouldBeMoreThanZero.selector);
        dSCEngine.mintDSC(0);
    }

    function test_mintDSCMintsCorrectAmountOfDSC() public hasDepositedCollatoral(USER) {
        uint256 amountToMint = 100;
        uint256 expectedDscBalance = amountToMint;

        vm.startPrank(USER);
        dSCEngine.mintDSC(amountToMint);
        vm.stopPrank();

        assertEq(decentralizedStableCoin.balanceOf(USER), expectedDscBalance);
    }

    /**
     *  getting the value of 3 eth, where 1 eth == $
     */
    function test_getAmountInUsd() public view {
        uint256 ethAmount = 3 ether; //
        uint256 amountInUsd = dSCEngine.getAmountInUsd(weth, ethAmount);
        uint256 expectedAmountInUSd = uint256(ETH_PRICE_USD) * ethAmount; // the USD value is in wei already
        assertEq(amountInUsd, expectedAmountInUSd);
    }

    /**
     * @notice collateral value should always be equal to the collateral desposited
     * @notice collateral desposit is the combination of all accepted token
     * desposited , weth ,wbtc desposited by the user. We are  return the  usd equivalent
     * @notice in this test, the user has deposit weth and wbtc in the
     *   modifier hasDepositedCollatoral
     */
    function test_getAccountCollateralValue() public hasDepositedCollatoral(USER) {
        // arrange ,act , assert

        uint256 userTotalCOllateral = dSCEngine.getAccountCollateralValueInUsd(USER);
        // user has deposit weth and wbtc
        // eth and btc have different price in usd .
        uint256 expectedValue = (AMOUNT_DEPOSITED * uint256(ETH_PRICE_USD));

        assertEq(userTotalCOllateral, expectedValue);
    }

    //Constructor Tests

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function test_RevertsWhenTokenAddressesAndPriceFeedAddressesAreOfDifferentLength() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUSDPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine__tokenAdressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(decentralizedStableCoin));
    }

    // Redeeming Collateral Tests

    function test_redeemCollateralRevertsWhenAmountIsZero() public hasDepositedCollatoral(USER) {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__ShouldBeMoreThanZero.selector);
        dSCEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }
    /**
     * @notice redeemCollateral should revert when the user has not deposited any collateral
     * the modifier hasDepositedCollatoral is not added here
     */

    function test_redeemCollateralRevertsWhenUserHasNotDepositedCollateral() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__UserHasNotDepositedCollateral.selector);
        dSCEngine.redeemCollateral(weth, AMOUNT_DEPOSITED);
        vm.stopPrank();
    }
    // when user tries to redeem more than the collateral deposited

    function test_redeemCollateralRevertsWhenUserTriesToRedeemMoreThanCollateralDeposited()
        public
        hasDepositedCollatoral(USER)
    {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__UserDoesNotHaveEnoughCollateral.selector);
        dSCEngine.redeemCollateral(weth, AMOUNT_DEPOSITED + 1);
        vm.stopPrank();
    }

    // burning the DSC
    function test_redeemCollateralBurnsDSC() public hasDepositedCollatoral(USER) {
        vm.startPrank(USER);

        dSCEngine.mintDSC(AMOUNT_DEPOSITED);
        uint256 startingDscBalance = decentralizedStableCoin.balanceOf(USER);
        console.log("DSC balance of user before burning", startingDscBalance);
        console.log("DSC minted by USER with an amount of ", AMOUNT_DEPOSITED);
        decentralizedStableCoin.approve(address(dSCEngine), AMOUNT_DEPOSITED);
        dSCEngine.redeemCollateralForDSC(weth, AMOUNT_DEPOSITED, AMOUNT_DEPOSITED);
        console.log("DSC burned by USER with an amount of ", AMOUNT_DEPOSITED);
        console.log("DSC balance of user after burning", decentralizedStableCoin.balanceOf(USER));
        vm.stopPrank();
        uint256 endingDscBalance = decentralizedStableCoin.balanceOf(USER);
        assertEq(endingDscBalance, 0);
    }

    function test_redeemCollateralReducesUserCollateralDeposited() public hasDepositedCollatoral(USER) {
        uint256 startingCollateralDeposited = dSCEngine.getCollateralDeposited(USER, weth);
        vm.startPrank(USER);
        dSCEngine.redeemCollateral(weth, AMOUNT_DEPOSITED);
        vm.stopPrank();
        uint256 endingCollateralDeposited = dSCEngine.getCollateralDeposited(USER, weth);
        uint256 expectedEndingCollateralDeposited = startingCollateralDeposited - AMOUNT_DEPOSITED;
        assertEq(endingCollateralDeposited, expectedEndingCollateralDeposited);
    }

    // liquidation tests
    function test_liquidateCollateralRevertsWhenAmountIsZero() public hasDepositedCollatoral(USER) {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__ShouldBeMoreThanZero.selector);
        dSCEngine.liquidate(weth, USER, 0);
        vm.stopPrank();
    }

    function test_CannotLiquidateCollateralWhenUserHasGoodHealthFactor() public hasDepositedCollatoral(USER) {
        vm.startPrank(USER_2);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        dSCEngine.liquidate(weth, USER, AMOUNT_DEPOSITED);
        vm.stopPrank();
    }

    function test_CanLiquidateCollateralWhenUserHasBadHealthFactor()
        public
        hasDepositedCollatoral(USER)
        hasDepositedCollatoral(USER_2)
    {
        vm.startPrank(USER);
        console.log(" user health factor before mint", dSCEngine.getHealthFactor(USER));

        // user  will mint DSC

        dSCEngine.mintDSC(AMOUNT_DEPOSITED);
        // the user will be overcollatrized and health factor will be bad
        console.log("DsC minted by user             ", dSCEngine.getDscMintedBy(USER));
        console.log(" user health factor after  mint", dSCEngine.getHealthFactor(USER));

        vm.stopPrank();
    }

    // getting collateral value in usd
    function test_getCollateralValueInUsd() public hasDepositedCollatoral(USER) {
        uint256 collateralValueInUsd = dSCEngine.getAccountCollateralValueInUsd(USER);
        // getting pricefeed from aggregatorV3
        (, int256 EthPriceInteger,,,) = AggregatorV3Interface(ethUSDPriceFeed).latestRoundData();
        uint256 EthPrice = uint256(EthPriceInteger) * PRICE_PRECISION_CHAINLINK; // add decimals to make to reach 1e18

        uint256 expectedCollateralValueInUsd = AMOUNT_DEPOSITED * EthPrice / PRECISION;
        console.log("Collateral value in usd", collateralValueInUsd);
        console.log("Expected Collateral value in usd", expectedCollateralValueInUsd);
        assertEq(collateralValueInUsd, expectedCollateralValueInUsd);
    }

    // getting health factor
    function test_getHealthFactor() public hasDepositedCollatoral(USER) {
        uint256 healthFactor = dSCEngine.getHealthFactor(USER);
        console.log("Health Factor", healthFactor);
        console.log("Collaoateral value in usd", dSCEngine.getAccountCollateralValueInUsd(USER));
        uint256 expectedHealthFactor = type(uint256).max;
        assertEq(healthFactor, expectedHealthFactor);
    }
}
