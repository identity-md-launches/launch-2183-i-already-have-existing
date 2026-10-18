// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @dev Deliberately adversarial ERC20; never a deployment dependency.
contract MockToken {
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool) public blocked;
    uint256 public tax;
    bool public falseAfterTransfer;
    bool public omitReturn;
    address public callback;
    bool public callbackSucceeded;
    bytes public callbackResult;
    bytes public callbackData;

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setBlocked(address to, bool value) external {
        blocked[to] = value;
    }

    function setTax(uint256 value) external {
        tax = value;
    }

    function setFalseAfterTransfer(bool value) external {
        falseAfterTransfer = value;
    }

    function setOmitReturn(bool value) external {
        omitReturn = value;
    }

    function setCallback(address to, bytes calldata data) external {
        callback = to;
        callbackData = data;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        return _move(msg.sender, to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        return _move(from, to, amount);
    }

    function _move(address from, address to, uint256 amount) private returns (bool) {
        require(!blocked[to], "recipient blocked");
        balanceOf[from] -= amount;
        balanceOf[to] += amount - amount * tax / 10_000;
        if (callback != address(0)) (callbackSucceeded, callbackResult) = callback.call(callbackData);
        if (omitReturn) {
            assembly ("memory-safe") { return(0, 0) }
        }
        return !falseAfterTransfer;
    }
}
