# kipu-bank

Contrato inteligente que permite a los usuarios depositar y retirar ETH en una bóveda personal, aplicando límites por transacción y un límite global de fondos (BankCap).

Este proyecto forma parte del Módulo 2 del curso Ethereum Developer Pack de la Fundación Kipu.

---

## Descripción

KipuBank permite:

- Depositar ETH en una bóveda personal.  
- Retirar ETH hasta un límite por transacción (`withdrawalLimit`).  
- Operar bajo un límite global acumulado de fondos (`bankCap`).  
- Registrar el número de depósitos y retiros realizados por usuario.  

El contrato aplica buenas prácticas de seguridad, errores personalizados y emisión de eventos en cada operación.

---

## Funcionalidades

| Función | Descripción |
|---------|-------------|
| `deposit()` | Depositar ETH. Valida que `totalDeposits + msg.value <= bankCap`. |
| `withdraw(uint256 _amount)` | Retirar ETH hasta `withdrawalLimit` y saldo disponible. |
| `getBalance(address _user)` | Consultar saldo de un usuario en wei. |
| `bankCap` | Límite global acumulado de ETH (inmutable). |
| `withdrawalLimit` | Límite máximo de retiro por transacción (inmutable). |
| `totalDeposits` | Saldo total actual del contrato. |
| `depositCount`, `withdrawalCount` | Contadores de operaciones por usuario. |
| `receive()` | Permite recibir ETH directamente, redirige a `deposit()`. |

---

## Constructor

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `_bankCap` | `uint256` | Límite máximo total de ETH del contrato. |
| `_withdrawalLimit` | `uint256` | Límite máximo de retiro por transacción. |

---

## Despliegue (Remix + Sepolia)

1. Abrir Remix IDE: [https://remix.ethereum.org](https://remix.ethereum.org)  
2. Crear archivo `KipuBank.sol` y pegar el contrato.  
3. Compilar:  
   - Versión 0.8.20  
   - Optimización activada  
4. Desplegar:  
   - Entorno: Injected Provider (MetaMask)  
   - Red: Sepolia Testnet  
   - Parámetros de ejemplo: `_bankCap = 2 ether`, `_withdrawalLimit = 1 ether`  
5. Confirmar la transacción en MetaMask.  
6. (Opcional) Verificar contrato en Sepolia Etherscan.

---

## Uso principal

- **Depositar ETH**: llamar `deposit()` con valor en ETH.  
- **Retirar ETH**: llamar `withdraw(uint256 _amount)` en wei.  
- **Consultar saldo**: llamar `getBalance(address)`.

---

## Casos de uso resumidos

| Caso de uso | Descripción | Resultado esperado |
|------------|-------------|------------------|
| Depósito válido | Depositar dentro de `bankCap` | Saldo incrementado, evento `Deposit`, contador actualizado |
| Retiro válido | Retiro dentro de `withdrawalLimit` y saldo suficiente | Saldo decrementado, evento `Withdrawal`, contador actualizado |
| Retiro que excede límite | Retiro mayor a `withdrawalLimit` | Revert `KipuBank__ExceedsWithdrawalLimit()` |
| Depósito que excede `bankCap` | Depositar más que capacidad total del contrato | Revert `KipuBank__BankCapReached()` |
| Retiro con saldo insuficiente | Retiro mayor al saldo disponible | Revert `KipuBank__InsufficientBalance()` |
| Envío directo de ETH | Enviar ETH sin llamar a `deposit()` | Se ejecuta `receive()`, evento `Deposit` emitido |
| Monto cero | Depositar o retirar 0 | Revert `KipuBank__ZeroAmount()` |
| BankCap acumulado con varios usuarios | Depósitos combinados alcanzando `bankCap` | Reverts al superar `bankCap` |

> Para todos los escenarios detallados, consulte [TEST_CASES.md](./TEST_CASES.md)

---

## Seguridad y optimización

- Variables `immutable` para menor consumo de gas.  
- Errores personalizados en lugar de strings largos.  
- Patrón checks-effects-interactions.  
- Modificador `nonZero` para evitar operaciones con monto 0.  
- Incrementos con `unchecked` donde es seguro.  
- Transferencias seguras usando `call{value: ...}`.  
