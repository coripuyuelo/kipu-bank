// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title KipuBank - native ETH vault per user
/// @author Corina Puyuelo
/// @notice This contract allows users to deposit and withdraw ETH up to a per-tx withdrawalLimit and global bankCap.
/// @dev Follows checks-effects-interactions, custom errors, and minimized storage accesses.

contract KipuBank {

    // ===== VARIABLES =====

    /// @notice Maximum total ETH the contract accepts (set at deployment)
    uint256 public immutable bankCap;

    /// @notice Maximum amount a user can withdraw in a single transaction (set at deployment)
    uint256 public immutable withdrawalLimit;

    /// @notice User balances (vault)
    mapping(address => uint256) private balances;

    /// @notice Number of deposits per user
    mapping(address => uint256) public depositCount;

    /// @notice Number of withdrawals per user
    mapping(address => uint256) public withdrawalCount;

    /// @notice Current total deposits stored in the contract
    uint256 public totalDeposits;

    // ===== REENTRANCY GUARD =====

    // Using simple guard pattern; 1 = unlocked, 2 = locked
    uint256 private _locked = 1;

    // ===== EVENTS =====

    /// @notice Emitted when a user deposits ETH
    /// @param user The depositor address
    /// @param amount The amount of ETH deposited (wei)
    event Deposit(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws ETH
    /// @param user The withdrawer address
    /// @param amount The amount withdrawn (wei)
    event Withdrawal(address indexed user, uint256 amount);

    // ===== ERRORS =====

    /// @notice Revert when zero amount is provided
    error ZeroAmount();

    /// @notice Revert when deposit would exceed bank cap
    error BankCapExceeded();

    /// @notice Revert when requested withdrawal is above per-tx limit
    error ExceedsWithdrawalLimit();

    /// @notice Revert when user has insufficient funds
    error InsufficientBalance();

    /// @notice Revert when transfer via call fails
    error TransferFailed();

    /// @notice Revert when constructor params are invalid
    error InvalidParams();

    /// @notice Reentrancy attempt detected
    error Reentrancy();

    // ===== CONSTRUCTOR =====

    /// @notice Deploy the bank with a global cap and per-transaction withdrawal limit
    /// @param _bankCap Maximum total ETH the contract will hold (wei)
    /// @param _withdrawalLimit Maximum ETH allowed per withdrawal transaction (wei)
    constructor(uint256 _bankCap, uint256 _withdrawalLimit) {
        if (_bankCap == 0 || _withdrawalLimit == 0) revert InvalidParams();
        bankCap = _bankCap;
        withdrawalLimit = _withdrawalLimit;
    }

    // ===== MODIFIERS =====

    /// @notice Ensure non-zero amount argument
    /// @param _amount The amount to check
    modifier nonZero(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    /// @notice Simple reentrancy guard
    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ===== FUNCTIONS =====

    /// @notice Deposit ETH into sender's vault
    /// @dev Uses local variables to minimize storage reads/writes.
    function deposit() external payable nonZero(msg.value) {
        // read once
        uint256 currentTotal = totalDeposits;
        uint256 newTotal = currentTotal + msg.value;

        // check
        if (newTotal > bankCap) revert BankCapExceeded();

        // effects - minimize storage accesses by using locals
        uint256 userBalance = balances[msg.sender];
        userBalance += msg.value;
        // write back
        balances[msg.sender] = userBalance;

        // deposit count increment -- safe to use unchecked (practically impossible to overflow)
        unchecked { depositCount[msg.sender]++; }

        // update totalDeposits after the check (no overflow possible because newTotal <= bankCap)
        totalDeposits = newTotal;

        // interaction last (none here) and emit
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Withdraw up to withdrawalLimit in a single transaction
    /// @param _amount Amount in wei to withdraw
    function withdraw(uint256 _amount) external nonZero(_amount) nonReentrant {
        // read balance once
        uint256 userBalance = balances[msg.sender];

        // checks
        if (_amount > userBalance) revert InsufficientBalance();
        if (_amount > withdrawalLimit) revert ExceedsWithdrawalLimit();

        // effects
        uint256 newUserBalance = userBalance - _amount;
        balances[msg.sender] = newUserBalance;

        // update totalDeposits (we already ensured userBalance >= _amount so no underflow)
        // Using unchecked is safe because subtraction cannot underflow due to previous check.
        unchecked {
            totalDeposits -= _amount;
            withdrawalCount[msg.sender]++;
        }

        // interaction
        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(msg.sender, _amount);
    }

    /// @notice Returns the balance of a user
    /// @param _user Address to query
    /// @return balance The user's vault balance in wei
    function getBalance(address _user) external view returns (uint256 balance) {
        return balances[_user];
    }

    /// @notice Fallback receive to accept ETH directly
    /// @dev Mirrors deposit() logic but inlined for gas efficiency; uses same checks and effects.
    receive() external payable nonZero(msg.value) {
        uint256 currentTotal = totalDeposits;
        uint256 newTotal = currentTotal + msg.value;

        if (newTotal > bankCap) revert BankCapExceeded();

        uint256 userBalance = balances[msg.sender];
        userBalance += msg.value;
        balances[msg.sender] = userBalance;

        unchecked { depositCount[msg.sender]++; }

        totalDeposits = newTotal;

        emit Deposit(msg.sender, msg.value);
    }
}
