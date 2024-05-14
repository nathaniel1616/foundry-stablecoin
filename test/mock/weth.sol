//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract WETH is ERC20, ReentrancyGuard {
    error WETH__AmountCannotBeZero();
    error WETH__TransferFailed(uint256 amount);

    modifier AmountNotZero(uint256 _amount) {
        if (_amount == 0) {
            revert WETH__AmountCannotBeZero();
        }
        _;
    }

    // Layout of Functions:
    constructor() ERC20("Wrapped Ether", "WETH") {}

    receive() external payable {
        deposit();
    }

    // receive ether and mint weth
    function deposit() public payable AmountNotZero(msg.value) {
        _mint(msg.sender, msg.value);
    }

    // withdrawl burn weth and send ether
    function withdraw(uint256 _amount) public AmountNotZero(_amount) nonReentrant {
        _burn(msg.sender, _amount);
        (bool success,) = msg.sender.call{value: _amount}("");
        if (!success) {
            revert WETH__TransferFailed(_amount);
        }
    }
}
