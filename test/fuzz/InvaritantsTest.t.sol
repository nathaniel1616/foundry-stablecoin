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

contract InvariantsTest is StdInvariant, Test {
    DecentralizedStableCoin decentralizedStableCoin;
    DSCEngine dscEngine;
    HelperConfig helperConfig;
    DeployDecentralizedStableCoin deployDecentralizedStableCoin;
    Handler handler;
    address USER = makeAddr("USER");
    address weth;
    address wbtc;
    uint256 constant STARTING_AMOUNT = 1e30;

    function setUp() external {
        deployDecentralizedStableCoin = new DeployDecentralizedStableCoin();
        (decentralizedStableCoin, dscEngine, helperConfig) = deployDecentralizedStableCoin.run();
        (weth, wbtc,,,) = helperConfig.activateNetworkConfig();
        handler = new Handler(dscEngine, decentralizedStableCoin);
        targetContract(address(handler));
    }
    // invariant test

    function invariant_HandlerprotocolMustHaveMoreCollateralThanDSCSupply() public view {
        uint256 dscSupply = decentralizedStableCoin.totalSupply();

        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
        uint256 totalCollateral = totalWethDeposited + totalWbtcDeposited;
        // console.log("totalCollateral: ", totalCollateral);
        // console.log("dscSupply: ", dscSupply);

        assert(totalCollateral >= dscSupply);
    }
}
