// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../mock/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

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
    uint256 constant STARTING_AMOUNT = 5e30;
    uint256 constant AMOUNT_DEPOSITED = 3e18;
    int256 constant BTC_PRICE_USD = 600000; // $60,000U
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

    modifier hasDepositedCollatoral() {
        ERC20Mock(weth).mint(USER, STARTING_AMOUNT);
        ERC20Mock(wbtc).mint(USER, STARTING_AMOUNT);
        vm.startPrank(USER);
        IERC20(weth).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        dSCEngine.depositCollateral(weth, AMOUNT_DEPOSITED);

        IERC20(wbtc).approve(address(dSCEngine), AMOUNT_DEPOSITED);
        dSCEngine.depositCollateral(wbtc, AMOUNT_DEPOSITED);

        vm.stopPrank();

        console.log("WBTC and WETH minted to this address", USER);
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

        assertEq(startingUserDSCBalance, 0);
        assertEq(endingUserDSCBalance, AMOUNT_DEPOSITED);
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

    function test_mintDSCRevertsWhenAmountIsZero() public hasDepositedCollatoral {
        hoax(USER);
        vm.expectRevert(DSCEngine.DSCEngine__ShouldBeMoreThanZero.selector);
        dSCEngine.mintDSC(0);
    }

    function test_mintDSCMintsCorrectAmountOfDSC() public hasDepositedCollatoral {
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
    function test_getAccountCollateralValue() public hasDepositedCollatoral {
        // arrange ,act , assert

        uint256 userTotalCOllateral = dSCEngine.getAccountCollateralValue(USER);
        // user has deposit weth and wbtc
        // eth and btc have different price in usd .
        uint256 expectedValue =
            (AMOUNT_DEPOSITED * uint256(ETH_PRICE_USD)) + (AMOUNT_DEPOSITED * uint256(BTC_PRICE_USD));

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
}
