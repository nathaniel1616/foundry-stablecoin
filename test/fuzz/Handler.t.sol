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
    address weth;
    address wbtc;
    uint256 constant STARTING_AMOUNT = 1e30;
    address[] public hasCollateral;

    address public SelectedTokenAddress;

    address public MSG_SENDER;

    uint256 public NumOfRedeems;
    uint256 public NumOfMints;
    uint256 public NumOfDeposits;
    uint256 public NumofMints2;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _decentralizedStableCoin) {
        dscEngine = _dscEngine;
        decentralizedStableCoin = _decentralizedStableCoin;
        weth = dscEngine.getTokenaddress(0);
        wbtc = dscEngine.getTokenaddress(1);
    }

    function depositCollateral(uint256 collateralSwapper, uint96 _amount) public {
        _setTokenAddress(collateralSwapper);

        vm.assume(_amount > 0);
        vm.startPrank(msg.sender);
        ERC20Mock(SelectedTokenAddress).mint(msg.sender, _amount);
        //approving
        ERC20Mock(SelectedTokenAddress).approve(address(dscEngine), _amount);

        dscEngine.depositCollateral(SelectedTokenAddress, _amount);

        vm.stopPrank();
        MSG_SENDER = msg.sender;
        console.log("msg.sender in hanlder function : ", MSG_SENDER);
        NumOfDeposits++;
        hasCollateral.push(msg.sender);
    }
    // minting dsc

    function mintDSC(uint256 _amount, uint256 depositSeed) public {
        if (hasCollateral.length == 0) return;
        address sender = hasCollateral[depositSeed % hasCollateral.length];

        if (_amount == 0) return;
        // in order to mint DSC, user must have deposited collateral and good health factor
        // we must get account information of user
        (uint256 totalDscMinted, uint256 collateralDeposited) = dscEngine.getAccountInformation(sender);
        console.log("collateralDeposited: ", collateralDeposited);
        int256 maxDscToMint = (int256(collateralDeposited) / 2) - int256(totalDscMinted);
        vm.assume(maxDscToMint > 0);
        uint256 amount = bound(_amount, 1, uint256(maxDscToMint));

        vm.startPrank(sender);
        dscEngine.mintDSC(amount);
        vm.stopPrank();
        MSG_SENDER = sender;
        NumOfMints++;
    }

    // function mintDSC2(uint256 _amount) public {
    //     (uint256 totalDscMinted, uint256 collateralDeposited) = dscEngine.getAccountInformation(msg.sender);
    //     int256 maxDscToMint = (int256(collateralDeposited) / 2) - int256(totalDscMinted);

    //     console.log("maxDscToMint of the msg.sender: ", uint256(maxDscToMint));
    //     if (maxDscToMint < 0) {
    //         return;
    //     }
    //     console.log("before bound funct :", _amount);
    //     uint256 amount = bound(_amount, 0, uint256(maxDscToMint));
    //     console.log("bound ***amount variable in mint :", amount);
    //     if (_amount == 0) {
    //         return;
    //     }
    //     NumofMints2++;
    //     vm.startPrank(msg.sender);
    //     dscEngine.mintDSC(_amount);
    //     vm.stopPrank();
    // }
    //redeeming collateral

    function redeeemCollateral( /*uint256 collateralSwapper,*/ uint96 _amount, uint256 depositSeed) public {
        // _setTokenAddress(collateralSwapper);
        if (hasCollateral.length == 0) return;
        address sender = hasCollateral[depositSeed % hasCollateral.length];
        // possible ranges/ bounds  of  collateral a user can redeem
        uint256 maxUserDepositedCollateral = dscEngine.getCollateralDeposited(sender, SelectedTokenAddress);
        console.log("maxUserDepositedCollateral: ", maxUserDepositedCollateral);
        if (maxUserDepositedCollateral == 0) return;

        uint256 amount = bound(_amount, 1, maxUserDepositedCollateral);

        //  in order to successfully redeem collatoral , user health factor must be greater than min health factor
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(sender);
        uint256 amountToredeem = dscEngine.getAmountInUsd(SelectedTokenAddress, amount);
        uint256 expectedHealthFactor =
            dscEngine.calculatedHealthFactor(totalDscMinted, collateralValueInUsd - amountToredeem);
        console.log("expectedHealthFactor of redeemer: ", expectedHealthFactor);
        if (expectedHealthFactor < dscEngine.getMinimumHealthFactor()) return;
        vm.startPrank(sender);
        dscEngine.redeemCollateral(SelectedTokenAddress, amount);
        vm.stopPrank();

        NumOfRedeems++;
    }

    // helper function
    // get correct token address and Swap them randomly for handler
    function _setTokenAddress(uint256 collateralSwapper) private returns (address) {
        if (collateralSwapper % 2 == 0) {
            SelectedTokenAddress = weth;
            return SelectedTokenAddress;
        } else {
            SelectedTokenAddress = wbtc;
            return SelectedTokenAddress;
        }
    }
}
