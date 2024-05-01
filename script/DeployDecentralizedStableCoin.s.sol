// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDecentralizedStableCoin is Script {
    DecentralizedStableCoin decentralizedStableCoin;

    function run() external returns (DecentralizedStableCoin) {
        vm.startBroadcast();
        decentralizedStableCoin = new DecentralizedStableCoin();
        vm.stopBroadcast();
        return decentralizedStableCoin;
    }
}
