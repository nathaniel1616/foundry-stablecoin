// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {WETH} from "test/mock/weth.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployWeth} from "../../../script/DeployWeth.s.sol";

contract WethTest is Test {
    WETH public weth;

    address USER = makeAddr("USER");
    uint256 public constant STARTING_AMOUNT = 10 ether;
    uint256 public constant AMOUNT_DEPOSITED = 2 ether;

    function setUp() external {
        weth = new DeployWeth().run();
        vm.deal(USER, STARTING_AMOUNT);
    }

    function test_WethName() public view {
        assertEq(weth.name(), "Wrapped Ether");
    }

    function test_WethSymbol() public view {
        assertEq(weth.symbol(), "WETH");
    }

    function test_Deposit() public {
        vm.startPrank(USER);
        weth.deposit{value: AMOUNT_DEPOSITED}();
        vm.stopPrank();

        assertEq(weth.balanceOf(USER), AMOUNT_DEPOSITED);
    }

    function test_Withdraw() public {
        // arrange - check inital balances
        uint256 initialWethBalance = address(this).balance;

        // act - deposit, withdraw
        vm.startPrank(USER);
        weth.deposit{value: AMOUNT_DEPOSITED}();
        console.log("Received WETH");
        console.log(weth.balanceOf(USER));
        console.log(address(this).balance);

        weth.withdraw(AMOUNT_DEPOSITED);
        vm.stopPrank();

        //assert- balance

        assertEq(weth.balanceOf(USER), 0);
        assertEq(address(this).balance, initialWethBalance);
        assertEq(address(USER).balance, STARTING_AMOUNT);
    }

    // weth is burn when Eth is withdrawn
    function test_WethIsBurnWhenEthIsWithdrawn() public {
        // arrange - check inital balances
        uint256 initialEthBalance = address(this).balance;
        uint256 initialWethSupply = weth.totalSupply();
        console.log("initialWethSupply", initialWethSupply);
        console.log("initialEthBalance", initialEthBalance);
        // act - deposit, withdraw
        console.log("Starting Prank");
        vm.startPrank(USER);
        weth.deposit{value: AMOUNT_DEPOSITED}();
        console.log("Received WETH");
        console.log("Weth Current Supply", weth.totalSupply());
        console.log("Native Eth balance", address(this).balance);

        weth.withdraw(AMOUNT_DEPOSITED);
        console.log("Withdrawn WETH");
        vm.stopPrank();

        //assert- balance

        assertEq(weth.balanceOf(USER), 0);
        assertEq(weth.totalSupply(), 0);
    }
}
