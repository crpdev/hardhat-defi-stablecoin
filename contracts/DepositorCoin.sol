// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

import {ERC20} from "./ERC20.sol";

contract DepositorCoin is ERC20 {
    address public owner;

    constructor() ERC20("DepositorCoin", "DPTC") {
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(
            msg.sender == owner,
            "Only the owner is authorized to mint DepositorCoin"
        );
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(
            msg.sender == owner,
            "Only the owner is authorized to burn DepositorCoin"
        );
        _burn(from, amount);
    }
}
