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

    event CollateralDeposited(address indexed user, address indexed tokenAddress, uint256 indexed amount);

    function setUp() external {
        deployDecentralizedStableCoin = new DeployDecentralizedStableCoin();
        (decentralizedStableCoin, dSCEngine) = deployDecentralizedStableCoin.run();
        weth = deployDecentralizedStableCoin.weth();
        wbtc = deployDecentralizedStableCoin.wbtc();
        ethUSDPriceFeed = deployDecentralizedStableCoin.ethUSDPriceFeed();
        btcUsdPriceFeed = deployDecentralizedStableCoin.btcUsdPriceFeed();
        deployer = deployDecentralizedStableCoin.deployer();
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
        vm.expectRevert(DSCEngine.DSC__ShouldBeMoreThanZero.selector);
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

        vm.stopPrank();

        console.log("WBTC and WETH minted to this address", USER);
        _;
    }

    function test_depositCollateralRevertsWhenTOkenIsNotAllowed() public {
        ERC20Mock fakeToken = new ERC20Mock("FakeToken", "FK");
        fakeToken.mint(USER, STARTING_AMOUNT);

        console.log("Fake token has been minted ");
        hoax(USER);
        vm.expectRevert(DSCEngine.DSC__TokenNotAllowed.selector);
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

    // minting

    function test_mintDSCRevertsWhenAmountIsZero() public hasDepositedCollatoral {
        hoax(USER);
        vm.expectRevert(DSCEngine.DSC__ShouldBeMoreThanZero.selector);
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

    function test_mintDSCRevertsWhenHealthFactorIsBelowThreshold() public userHasWethAndWBTC {
        // Reduce user's health factor below the threshold
        vm.startPrank(USER);
        IERC20(weth).approve(address(dSCEngine), STARTING_AMOUNT);
        dSCEngine.depositCollateral(weth, STARTING_AMOUNT);

        // Attempt to mint DSC, which should fail due to low health factor

        vm.expectRevert();
        dSCEngine.mintDSC(STARTING_AMOUNT * 2);
        vm.stopPrank();
    }
}
