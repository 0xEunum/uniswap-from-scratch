# Math

## The constant product invariant

Every exchange enforces the invariant `x · y = k`, where `x` is the ETH reserve, `y` is the token reserve, and `k` is a constant that can only grow (it grows because fees stay in the pool). Before any swap, `x · y = k`. After a swap where you put in `Δx` and take out `Δy`, the invariant becomes:

```
(x + Δx) · (y - Δy) = k = x · y
```

This is the core rule: the product of the two reserves must not decrease.

---

## _getInputPrice — exact input, unknown output

You want to sell an exact amount `Δx` and find out how much `Δy` you get back. The fee is applied to the input: only 99.7% of `Δx` is counted toward moving the price. The other 0.3% stays in the pool.

Starting from the invariant with the fee applied:

```
(x + Δx · 997/1000) · (y - Δy) = x · y
```

Solving for `Δy`:

```
y - Δy = (x · y) / (x + Δx · 997/1000)

Δy = y - (x · y) / (x + Δx · 997/1000)

Δy = (Δx · 997 · y) / (x · 1000 + Δx · 997)
```

In the code (using integer arithmetic):

```solidity
uint256 inputAmountWithFee = _inputAmount * FEE_MULTIPLIER;         // Δx · 997
uint256 numerator = inputAmountWithFee * _outputReserve;            // Δx · 997 · y
uint256 denominator = (_inputReserve * FEE_DENOMINATOR) + inputAmountWithFee; // x·1000 + Δx·997
return numerator / denominator;
```

Integer division truncates, which rounds the output down — slightly in favor of the pool.

---

## _getOutputPrice — exact output, unknown input

You want to receive an exact amount `Δy` and find out how much `Δx` you need to pay. Same invariant, but now we solve for `Δx`:

```
(x + Δx · 997/1000) · (y - Δy) = x · y

x + Δx · 997/1000 = (x · y) / (y - Δy)

Δx · 997/1000 = (x · y) / (y - Δy) - x

Δx · 997/1000 = (x · y - x · (y - Δy)) / (y - Δy)

Δx · 997/1000 = (x · Δy) / (y - Δy)

Δx = (x · Δy · 1000) / ((y - Δy) · 997)
```

In the code:

```solidity
uint256 numerator = _inputReserve * _outputAmount * FEE_DENOMINATOR;  // x · Δy · 1000
uint256 denominator = (_outputReserve - _outputAmount) * FEE_MULTIPLIER; // (y - Δy) · 997
return (numerator / denominator) + 1;
```

The `+ 1` rounds the required input *up*. This is important: without it, a buyer could shave off a fractional token-wei of required input via integer truncation, which would mean the pool gets slightly less than it should. Rounding up protects the pool and the LPs.

---

## LP token mint formula

When the pool is not empty, the amount of LP tokens minted is proportional to how much ETH you're contributing relative to the existing ETH reserve:

```
liquidityMinted = msg.value * totalSupply / ethReserve
```

The token amount required from you is also proportional:

```
tokenAmount = msg.value * tokenReserve / ethReserve + 1
```

The `+ 1` here ensures the required token amount rounds up so the pool ratio doesn't shift against existing LPs.

For the very first deposit, there is no price ratio to maintain. The initial LP minted equals the ETH deposited in wei:

```
initialLiquidity = address(this).balance  // = msg.value after it arrives
```

And the token amount is exactly `_maxTokens` — whatever the first depositor provides sets the initial price.

---

## LP token burn formula

When you remove liquidity, you burn `amount` LP tokens and receive a proportional share of both reserves:

```
ethAmount   = amount * ethReserve   / totalSupply
tokenAmount = amount * tokenReserve / totalSupply
```

Integer division rounds down here, which means the pool keeps any fractional remainder — this is fine and expected behavior.
