# Uniswap From Scratch

Rebuilding Uniswap V1, V2, and V3 in Solidity from scratch using Foundry — one version at a time, as a deep-dive learning series. Each version lives in its own folder with its own README, tests, and documentation. The goal is to understand how each version of the protocol actually works at the code level, not just from a high level.

## Video Walkthrough

Coming soon.

<!-- TODO: paste YouTube link here -->

---

## Roadmap

| Version | Status | README |
|---------|--------|--------|
| V1 | ✅ Done | [src/v1/README.md](./src/v1/README.md) |
| V2 | 🔜 Upcoming | — |
| V3 | 🔜 Upcoming | — |

---

## Project Structure

```
uniswap-from-scratch/
├── src/
│   ├── v1/
│   │   ├── UniswapV1Factory.sol
│   │   ├── UniswapV1Exchange.sol
│   │   └── README.md              # V1 deep-dive
│   ├── v2/                        # upcoming
│   └── v3/                        # upcoming
├── test/
│   ├── v1/
│   │   └── unit/
│   └── v2/                        # upcoming
├── docs/
│   ├── v1/                        # V1 detailed docs
│   │   ├── ARCHITECTURE.md
│   │   ├── MATH.md
│   │   ├── LIQUIDITY.md
│   │   ├── SWAPS.md
│   │   └── TOKEN_TO_TOKEN.md
│   └── README.md                  # docs index
├── foundry.toml
└── README.md
```

---

## Build & Test

**Prerequisites:** [Foundry](https://book.getfoundry.sh/getting-started/installation)

```bash
# Install dependencies
forge install

# Compile
forge build

# Run all tests
forge test

# Coverage report
forge coverage
```

Each version's README has version-specific test counts and coverage numbers.
