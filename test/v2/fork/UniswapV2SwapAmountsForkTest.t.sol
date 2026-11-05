// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapV2RouterUnitTest} from "test/v2/unit/UniswapV2RouterUnitTest.t.sol";

interface IUniswapV2Router02 {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);
}

/**
 * @title UniswapV2SwapAmountsForkTest
 * @notice Demonstrates live multi-hop swap pricing against real Ethereum Mainnet Uniswap V2 pairs.
 * @dev WARNING: This test file ONLY works on a Mainnet fork environment!
 *
 * Running without `--fork-url mainnet` will fail because the token addresses (WETH, DAI, MKR)
 * and the Uniswap V2 Router exist only on Ethereum Mainnet.
 *
 * Command to run:
 *   forge test --match-test test_GetAmountsOutFork --fork-url mainnet -vv
 *   forge test --match-test test_GetAmountsInFork --fork-url mainnet -vv
 */
contract UniswapV2SwapAmountsForkTest is Test, UniswapV2RouterUnitTest {
    function setUp() public override {
        super.setUp();
    }

    function test_GetAmountsOutFork() public view {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountIn = 1 ether;
        uint256[] memory amounts = IUniswapV2Router02(address(router)).getAmountsOut(amountIn, path);

        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
    }

    // function _getAmountsOut(address _factory, uint256 _amountIn, address[] memory _path)
    //     internal
    //     view
    //     returns (uint256[] memory amounts)
    // {
    //     if (_path.length < 2) {
    //         revert UniswapV2Router__InvalidPath();
    //     }

    //     amounts = new uint256[](_path.length);
    //     amounts[0] = _amountIn;

    // NOTE: Example
    // --- Inputs ---
    // amountIn = 1e18
    // path = [WETH, DAI, MKR]
    // --- Outputs ---
    // WETH    1000000000000000000 (1 * 1e18)
    // DAI  2248459448448485649662 (2248.4594... * 1e18)
    // MKR        7625955990811795 (0.007625... * 1e18)

    // --- Execution ---
    // amounts = [0, 0, 0]
    // amounts = [1000000000000000000, 0, 0]

    // For loop
    // i = 0
    // path[i] = WETH, path[i + 1] = DAI
    // amounts[i] = 1000000000000000000
    // amounts[i + 1] = 2248459448448485649662
    // amounts = [1000000000000000000, 2248459448448485649662, 0]

    // i = 1
    // path[i] = DAI, path[i + 1] = MKR
    // amounts[i] = 2248459448448485649662
    // amounts[i + 1] = 7625955990811795
    // amounts = [1000000000000000000, 2248459448448485649662, 7625955990811795]

    // NOTE:
    //   i | path[i]   | path[i + 1]
    //   0 | path[0]   | path[1]
    //   1 | path[1]   | path[2]
    //   2 | path[2]   | path[3]
    // n-2 | path[n-2] | path[n-1]

    //     for (uint256 i = 0; i < _path.length - 1; i++) {
    //         (uint256 reserveIn, uint256 reserveOut) = _getReserves(_factory, _path[i], _path[i + 1]);
    //         amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
    //     }
    // }

    function test_GetAmountsInFork() public view {
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        uint256 amountOut = 0.005 ether; // 0.005 MKR

        uint256[] memory amounts = IUniswapV2Router02(address(router)).getAmountsIn(amountOut, path);

        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
    }

    // function _getAmountsIn(address _factory, uint256 _amountOut, address[] memory _path)
    //     internal
    //     view
    //     returns (uint256[] memory amounts)
    // {
    //     if (_path.length < 2) {
    //         revert UniswapV2Router__InvalidPath();
    //     }

    //     amounts = new uint256[](_path.length);
    //     amounts[_path.length - 1] = _amountOut;

    // --- Inputs ---
    // amountOut = 0.005e18
    // path = [WETH, DAI, MKR]
    // --- Outputs ---
    // WETH        9796518234752894 (0.009796... * 1e18)
    // DAI   22038429000152551409 (22.0384... * 1e18)
    // MKR       5000000000000000 (0.005 * 1e18)

    // --- Execution ---
    // amounts = [0, 0, 0]
    // amounts = [0, 0, 5000000000000000]

    // For loop
    // i = 2
    // path[i - 1] = DAI, path[i] = MKR
    // amounts[i] = 5000000000000000
    // amounts[i - 1] = 22038429000152551409
    // amounts = [0, 22038429000152551409, 5000000000000000]

    // i = 1
    // path[i - 1] = WETH, path[i] = DAI
    // amounts[i] = 22038429000152551409
    // amounts[i - 1] = 9796518234752894
    // amounts = [9796518234752894, 22038429000152551409, 5000000000000000]

    // NOTE:
    // i     | output amount  | input amount
    // n - 1 | amounts[n - 1] | amounts[n - 2]
    // n - 2 | amounts[n - 2] | amounts[n - 3]
    // ...
    // 2     | amounts[2]     | amounts[1]
    // 1     | amounts[1]     | amounts[0]

    //     for (uint256 i = _path.length - 1; i > 0; i--) {
    //         (uint256 reserveIn, uint256 reserveOut) = _getReserves(_factory, _path[i - 1], _path[i]);
    //         amounts[i - 1] = _getAmountIn(amounts[i], reserveIn, reserveOut);
    //     }
    // }
}
