// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../script/DeployDecentralizedStableCoin.s.sol";

contract DecentralizedStableCoinTest is Test {
    DeployDecentralizedStableCoin public deployDecentralizedStableCoin;
    DecentralizedStableCoin public decentralizedStableCoin;

    // variable and contanst
    address public Owner = makeAddr("Owner");
    address public USER = makeAddr("USER");
    uint256 public constant INITIAL_AMOUNT_MINTED = 9e21;
    uint256 public constant AMOUNT_TO_BURN = 1e18;

    function setUp() external {
        deployDecentralizedStableCoin = new DeployDecentralizedStableCoin();
        decentralizedStableCoin = deployDecentralizedStableCoin.run();
        vm.startBroadcast();
        decentralizedStableCoin.transferOwnership(Owner);
        // decentralizedStableCoin.mint(USER, INITIAL_AMOUNT_MINTED);
        vm.stopBroadcast();
    }

    function test_NameOfDecentralizedStableCoin() public view {
        assertEq(decentralizedStableCoin.name(), "DecentralizedStableCoin");
    }

    function test_OwnerOfStableCoin() public view {
        assertEq(decentralizedStableCoin.owner(), Owner);
    }

    function test_CanMintToken() public {
        vm.prank(Owner);
        decentralizedStableCoin.mint(USER, INITIAL_AMOUNT_MINTED);
    }

    /// have to mint token first before burning
    function test_CanBurnToken() public {
        vm.startPrank(Owner);
        decentralizedStableCoin.mint(Owner, INITIAL_AMOUNT_MINTED);
        uint256 startingBalance = decentralizedStableCoin.balanceOf(Owner);
        console.log(startingBalance);
        decentralizedStableCoin.burn(AMOUNT_TO_BURN);

        vm.stopPrank();

        uint256 endingBalance = decentralizedStableCoin.balanceOf(Owner);
        assertEq(startingBalance - endingBalance, AMOUNT_TO_BURN);
    }
}
