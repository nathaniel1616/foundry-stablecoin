// Handler is going to narrow down the way we call function

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mock/MockERC20.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin decentralizedStableCoin;
    address USER = makeAddr("USER");
    address weth;
    address wbtc;
    uint256 constant STARTING_AMOUNT = 1e30;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _decentralizedStableCoin) {
        dscEngine = _dscEngine;
        decentralizedStableCoin = _decentralizedStableCoin;
        weth = dscEngine.getTokenaddress(0);
        wbtc = dscEngine.getTokenaddress(1);
    }

    function depositCollateral(uint256 collateralSwapper, uint96 _amount) public {
        address tokenAddress = _swapTokenAddress(collateralSwapper);
        vm.assume(_amount > 0);
        vm.startPrank(USER);
        ERC20Mock(tokenAddress).mint(USER, _amount);
        //approving
        ERC20Mock(tokenAddress).approve(address(dscEngine), _amount);

        dscEngine.depositCollateral(tokenAddress, _amount);
        vm.stopPrank();
    }

    // helper function
    // get correct token address and Swap them randomly for handler
    function _swapTokenAddress(uint256 collateralSwapper) private view returns (address) {
        if (collateralSwapper % 2 == 0) {
            return weth;
        } else {
            return wbtc;
        }
    }
}
