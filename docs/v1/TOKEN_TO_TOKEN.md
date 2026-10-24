# Token-to-Token

## Routing through ETH

Source: [`UniswapV1Exchange.sol` — `_tokenToTokenInput` / `_tokenToTokenOutput`](../../src/v1/UniswapV1Exchange.sol)

Every Uniswap V1 exchange only pairs one ERC-20 token with ETH. There are no direct token-to-token pools. To swap Token A for Token B, the exchange routes through ETH:

1. Token A is sold on Exchange A → ETH is received
2. That ETH is immediately forwarded to Exchange B → Token B is received

This means every token-to-token swap pays the 0.3% fee twice — once on each leg.

---

## How _tokenToTokenInput works

For the input variant (exact Token A in):

1. Calculate `ethBought = _getInputPrice(tokensSold, tokenReserve, ethReserve)` on Exchange A
2. Check `ethBought >= _minEthBought` (slippage guard on the ETH leg)
3. Pull Token A from buyer: `I_TOKEN.transferFrom(buyer, address(this), tokensSold)`
4. Call `exchangeB.ethToTokenTransferInput{value: ethBought}(minTokensBought, deadline, recipient)`

Exchange B runs its own `_ethToTokenInput` logic and sends Token B directly to the recipient.

## How _tokenToTokenOutput works

For the output variant (exact Token B out):

1. Ask Exchange B how much ETH it needs: `ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought)`
2. Check `ethBought <= _maxEthSold` (slippage guard on the ETH leg)
3. Calculate how many Token A that ETH costs: `tokensSold = _getOutputPrice(ethBought, tokenReserve, ethReserve)` on Exchange A
4. Check `tokensSold <= _maxTokensSold` (slippage guard on Token A)
5. Pull Token A from buyer: `I_TOKEN.transferFrom(buyer, address(this), tokensSold)`
6. Call `exchangeB.ethToTokenTransferOutput{value: ethBought}(tokensBought, deadline, recipient)`

---

## Factory lookup

The `tokenToTokenSwap*` and `tokenToTokenTransfer*` variants look up Exchange B from the factory:

```solidity
address exchangeAddress = IUniswapV1Factory(I_FACTORY).getExchangeAddr(_tokenAddress);
```

`I_FACTORY` is stored as `address` (not the interface type) and cast inline when calling `getExchangeAddr`. If no exchange has been registered for `_tokenAddress`, the factory returns `address(0)`, and the `validExchange` modifier catches it and reverts.

---

## tokenToExchange variants

The `tokenToExchangeSwap*` and `tokenToExchangeTransfer*` functions skip the factory lookup entirely. Instead, you pass the destination exchange address directly. They call the same `_tokenToTokenInput` / `_tokenToTokenOutput` private functions with your provided `_exchangeAddress`.

This is useful if you already know the exchange address and want to save the factory lookup gas, or if you want to route to a specific exchange that isn't registered in this factory.

---

## validExchange modifier

Both private implementations apply the `validExchange` modifier to `_exchangeAddress`:

```solidity
modifier validExchange(address _exchangeAddress) {
    if (_exchangeAddress == address(0) || _exchangeAddress == address(this)) {
        revert UniswapV1Exchange__InvalidExchangeAddress();
    }
    _;
}
```

It rejects:
- `address(0)` — factory returned nothing (token not registered)
- `address(this)` — trying to route to yourself, which would create a circular call
