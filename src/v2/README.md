# Uniswap V2 from Scratch

An educational project rebuilding Uniswap V2 from scratch using **Solidity ^0.8.30** and **Foundry**, as part of my V1 → V2 → V3 AMM learning series.

I created this project to deepen my understanding of how automated market makers work under the hood, documenting what I learn through [Cyfrin Updraft](https://updraft.cyfrin.io/) in courses instructed by [Smart Contract Programmer](https://www.youtube.com/@smartcontractprogrammer).

---

## Architecture & Scope

Rather than splitting the codebase into two separate repositories with dozens of auxiliary libraries and interfaces, this project consolidates the core protocol mechanics into **3 primary contracts**:

```
src/v2/
├── UniswapV2Pair.sol      # Core AMM pool, LP token + permit, TWAP accumulators, flash swaps
├── UniswapV2Factory.sol   # Pair registry & deterministic CREATE2 deployment
└── UniswapV2Router.sol    # Multi-hop swap routing, liquidity management & price calculation
```

1. **`UniswapV2Pair.sol`**: Manages the pooled reserves of any ERC-20 ↔ ERC-20 token pair, enforces the $x \cdot y = k$ constant product invariant, tracks cumulative prices for TWAP oracles, supports flash swaps, and issues LP shares (with EIP-2612 permit).
2. **`UniswapV2Factory.sol`**: Serves as the central registry, mapping token pairs to their unique pool address and deploying new pairs deterministically using `CREATE2`.
3. **`UniswapV2Router.sol`**: The user-facing periphery entry point that handles slippage protection, deadlines, multi-hop swaps, and native ETH/WETH wrapping and unwrapping.

---

## Differences from the Original

- **Modern Solidity & No SafeMath:** The original Uniswap V2 contracts were written in Solidity `0.5.16` and relied on `SafeMath` for arithmetic. This implementation uses modern Solidity (`0.8.x`), which has built-in overflow/underflow checks. `SafeMath` is completely omitted, using `unchecked` blocks only where intentional wrapping is required (such as TWAP cumulative price accumulators).
- **Consolidated 3-Contract Design:** The goal is educational clarity and focus. Essential library formulas (like `quote`, `getAmountOut`, `getAmountIn`, and deterministic address computation) and token logic are directly integrated into the core 3 contracts rather than fragmented across separate packages.
- **LP Token & Permit:** Pair contracts inherit OpenZeppelin's `ERC20Permit` for gas-efficient, modern EIP-2612 gasless approvals without custom cryptographic boilerplate.

---

## References & Credits

- [Uniswap V2 Core](https://github.com/Uniswap/v2-core) — Original core contracts (`UniswapV2Pair`, `UniswapV2Factory`).
- [Uniswap V2 Periphery](https://github.com/Uniswap/v2-periphery) — Original periphery contracts (`UniswapV2Router02`).
- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf) — Hayden Adams, Noah Zinsmeister, and Dan Robinson.
- [Cyfrin Updraft](https://updraft.cyfrin.io/) — Smart contract development courses.
- [Smart Contract Programmer](https://www.youtube.com/@smartcontractprogrammer) — Video walkthroughs and lessons explaining Uniswap V2 mechanics.
