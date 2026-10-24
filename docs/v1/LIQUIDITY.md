# Liquidity

## addLiquidity

Source: [`UniswapV1Exchange.sol` — `addLiquidity`](../../src/v1/UniswapV1Exchange.sol)

`addLiquidity` is `payable`. The ETH you send is one side of the deposit. The token side is pulled from your wallet via `transferFrom`, so you need to approve the exchange first.

### First deposit

When `totalSupply() == 0` the pool is empty and there is no existing price ratio to respect. The rules are simpler:

- You must send at least 1 gwei (10⁹ wei) of ETH — the contract enforces a `1_000_000_000` minimum to prevent dust attacks on the initial price.
- The token amount deposited is exactly `_maxTokens`. Whatever ratio you choose sets the initial price.
- LP tokens minted equal `address(this).balance` in wei — i.e., exactly the ETH you sent.

### Subsequent deposits

Once liquidity exists, new deposits must respect the current price ratio. The required token amount is calculated from the current reserves:

```
tokenAmount = msg.value * tokenReserve / ethReserve + 1
```

The `+ 1` rounds the required token amount up so the pool ratio can't be gamed by depositing just below the correct amount. If you pass `_maxTokens` less than `tokenAmount`, the call reverts.

LP tokens minted are proportional to the ETH contribution:

```
liquidityMinted = msg.value * totalSupply / ethReserve
```

If `liquidityMinted` is less than `_minLiquidity`, the call reverts. The `_minLiquidity` parameter is your slippage guard — it protects you from frontrunning between when you calculated expected LP tokens and when your transaction lands.

---

## removeLiquidity

Source: [`UniswapV1Exchange.sol` — `removeLiquidity`](../../src/v1/UniswapV1Exchange.sol)

`removeLiquidity` burns `_amount` LP tokens and sends back a proportional share of both reserves:

```
ethAmount   = _amount * ethReserve   / totalSupply
tokenAmount = _amount * tokenReserve / totalSupply
```

Both are checked against your slippage minimums — `_minEth` and `_minTokens`. If either is below your minimum, the call reverts.

Execution order:
1. LP tokens are burned from `msg.sender`.
2. ETH is sent to `msg.sender`.
3. Tokens are transferred to `msg.sender`.

There's no reentrancy guard on this function, though the LP burn happens before any external calls.
