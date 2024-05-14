// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {WETH} from "../test/mock/weth.sol";

contract DeployWeth is Script {
    function run() external returns (WETH weth) {
        console.log("Deploying WETH");
        // Deploy WETH
        // WETH is ERC20, ReentrancyGuard
        // WETH has a constructor

        vm.startBroadcast();
        weth = new WETH();
        vm.stopBroadcast();
    }
}
