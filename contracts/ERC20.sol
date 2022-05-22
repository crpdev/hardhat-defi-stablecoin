// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

contract ERC20 {
    uint256 public totalSupply;
    string public name;
    string public symbol;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed sender,
        uint256 value
    );

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        // _mint(msg.sender, 100e18); MINTING IS HANDLED BY THE RESPECTIVE COIN IMPLEMENTATIONS
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Minting to zero address");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(from != address(0), "Burning to zero address");
        totalSupply -= amount;
        balanceOf[from] -= amount;
        emit Transfer(from, address(0), amount);
    }

    function approve(address owner, uint256 amount) external returns (bool) {
        require(owner != address(0), "Approval for zero address");
        allowance[msg.sender][owner] = amount;
        emit Approval(msg.sender, owner, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        uint256 currentAllowance = allowance[sender][msg.sender];
        require(currentAllowance >= amount, "Amount exceeds allowance");
        allowance[sender][msg.sender] = currentAllowance - amount;
        emit Approval(sender, msg.sender, allowance[sender][msg.sender]);
        return _transfer(sender, recipient, amount);
    }

    function transfer(address recipient, uint256 amount)
        external
        returns (bool)
    {
        return _transfer(msg.sender, recipient, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private returns (bool) {
        require(recipient != address(0), "Sending to zero address");
        uint256 senderBalance = balanceOf[sender];
        require(
            senderBalance >= amount,
            "Amount exceeds sender available balance"
        );
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }
}
