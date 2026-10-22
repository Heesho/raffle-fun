// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @notice GENERATED SCRATCH MOCK (S6 attempt-02): standard six-decimal ERC-20 standing in for canonical USDC.
/// @dev Fee-free, non-rebasing, reverts on failure (the trust model DESIGN.md assigns to USDC). Adds cumulative
///      per-address flow counters for conservation properties and an optional USDC-like blocklist used only by
///      scenario tests. OpenZeppelin ERC20.sol is not among the provided dependencies, so this is hand-written.
contract MockUSDC {
    string public constant name = "Mock USD Coin";
    string public constant symbol = "mUSDC";
    uint8 public constant decimals = 6;

    uint256 public totalSupply;
    mapping(address account => uint256 amount) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;
    mapping(address account => uint256 amount) public totalSentBy;
    mapping(address account => uint256 amount) public totalReceivedBy;
    mapping(address account => bool blocked) public blocklisted;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function setBlocklisted(address account, bool blocked) external {
        blocklisted[account] = blocked;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "MockUSDC: allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(to != address(0), "MockUSDC: zero to");
        require(!blocklisted[msg.sender] && !blocklisted[from] && !blocklisted[to], "MockUSDC: blocklisted");
        require(balanceOf[from] >= amount, "MockUSDC: balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        totalSentBy[from] += amount;
        totalReceivedBy[to] += amount;
        emit Transfer(from, to, amount);
    }
}
