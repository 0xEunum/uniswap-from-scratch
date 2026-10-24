# Swaps

## ETH-to-Token

Source: [`UniswapV1Exchange.sol` — `_ethToTokenInput` / `_ethToTokenOutput`](../../src/v1/UniswapV1Exchange.sol)

You send ETH with your transaction (`msg.value`) and receive ERC-20 tokens. There are two variants:

**Input** (`ethToTokenSwapInput`, `ethToTokenTransferInput`) — you specify the exact ETH amount (it's `msg.value`) and receive however many tokens the formula gives you, as long as it meets your `_minTokens` slippage floor.

**Output** (`ethToTokenSwapOutput`, `ethToTokenTransferOutput`) — you specify the exact number of tokens you want, and the contract calculates how much ETH that costs. You send the maximum ETH you're willing to pay (`msg.value`), the exact cost is deducted, and any unused ETH is refunded to you.

### Why ETH reserve subtracts msg.value

Inside `_ethToTokenInput`, the eth reserve used for pricing is:

```solidity
uint256 ethReserve = address(this).balance - _ethSold;
```

By the time this line executes, `msg.value` has already been deposited into the contract (ETH arrives with the call). So `address(this).balance` already includes the ETH you're selling. Subtracting it out gives us the reserve as it was *before* the trade — which is what the constant-product formula needs.

The same applies in `_ethToTokenOutput`:

```solidity
uint256 ethReserve = address(this).balance - _maxEth;
```

The token side doesn't need this adjustment because tokens haven't been pulled yet when the price is calculated.

---

## Token-to-ETH

Source: [`UniswapV1Exchange.sol` — `_tokenToEthInput` / `_tokenToEthOutput`](../../src/v1/UniswapV1Exchange.sol)

You sell ERC-20 tokens and receive ETH. Same input/output and swap/transfer naming as above.

**Input** — you specify the exact token amount you're selling. The formula tells you how much ETH you get. You set a `_minEth` floor.

**Output** — you specify the exact ETH you want to receive. The formula tells you how many tokens that costs. You set a `_maxTokens` ceiling.

### Reentrancy note

In `_tokenToEthInput`, the order of operations is:

1. Calculate `ethBought`
2. Send ETH to `_recipient`
3. Pull tokens from `_buyer` via `transferFrom`

The ETH goes out *before* the tokens come in. This matches the original Uniswap V1 Vyper design, but it means that if `_recipient` is a contract, it can re-enter the exchange before its token debt is settled. See the Limitations section in the README for more context.

---

## Swap vs Transfer

Every swap direction has two public entry points:

- `*Swap*` — output goes to `msg.sender`. No recipient parameter.
- `*Transfer*` — output goes to a `_recipient` you specify. The `validRecipient` modifier rejects `address(0)` and `address(this)`.

The private implementations (`_ethToTokenInput`, `_ethToTokenOutput`, `_tokenToEthInput`, `_tokenToEthOutput`) accept both a `_buyer` and a `_recipient` argument, so both patterns share the same core logic.
