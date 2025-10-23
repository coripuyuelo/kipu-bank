// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title KipuBank - Contrato inteligente de tokens nativos ETH
/// @author Corina Puyuelo
/// @notice Permite a los usuarios depositar y retirar ETH.
contract KipuBank {

    // ===== VARIABLES =====

    /// @notice Limite de ETH que puede almacenar el contrato
    uint256 public immutable bankCap;

    /// @notice Limite de retiro por transacción
    uint256 public immutable withdrawalLimit;

    /// @notice Balance por usuario
    mapping(address => uint256) private balances;

    /// @notice Depositos por usuario
    mapping(address => uint256) public depositCount;

    /// @notice Retiros por usuario
    mapping(address => uint256) public withdrawalCount;

    /// @notice Depositos del contrato
    uint256 public totalDeposits;

    // Simple reentrancy guard
    uint256 private _locked = 1;

    // ===== EVENTS =====

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    // ===== ERRORS =====

    error ZeroAmount();
    error BankCapReached();
    error ExceedsWithdrawalLimit();
    error InsufficientBalance();
    error TransferFailed();
    error InvalidParams();
    error Reentrancy();

    // ===== CONSTRUCTOR =====

    constructor(uint256 _bankCap, uint256 _withdrawalLimit) {
        if (_bankCap == 0 || _withdrawalLimit == 0) revert InvalidParams();
        bankCap = _bankCap;
        withdrawalLimit = _withdrawalLimit;
    }

    // ===== MODIFIERS =====

    modifier nonZero(uint256 _amount) {
        if (_amount == 0) revert ZeroAmount();
        _;
    }

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // ===== FUNCTIONS =====

    /// @notice Permite depositar ETH en la cuenta del usuario
    function deposit() external payable nonZero(msg.value) {
        if (totalDeposits + msg.value > bankCap) revert BankCapReached();
        _handleDeposit(msg.sender, msg.value);
    }

    /// @notice Permite retirar ETH hasta limite por TX
    function withdraw(uint256 _amount) external nonZero(_amount) nonReentrant {
        if (_amount > balances[msg.sender]) revert InsufficientBalance();
        if (_amount > withdrawalLimit) revert ExceedsWithdrawalLimit();

        // effects
        balances[msg.sender] -= _amount;
        totalDeposits -= _amount;
        unchecked { withdrawalCount[msg.sender]++; }

        // interaction
        (bool success, ) = msg.sender.call{value: _amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(msg.sender, _amount);
    }

    /// @notice Retorna el balance de un usuario
    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }

    /// @notice Permite recibir depositos
    receive() external payable {
        if (msg.value == 0) revert ZeroAmount();
        if (totalDeposits + msg.value > bankCap) revert BankCapReached();
        _handleDeposit(msg.sender, msg.value);
    }

    /// @notice Funcion privada

    function _handleDeposit(address _from, uint256 _amount) private {
        unchecked {
            balances[_from] += _amount;
            depositCount[_from]++;
        }
        totalDeposits += _amount;
        emit Deposit(_from, _amount);
    }
}
