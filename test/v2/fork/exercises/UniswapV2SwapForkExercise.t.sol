// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {console2} from "forge-std/Console2.sol";

import {UniswapV2TestSetUp} from "test/v2/UniswapV2TestSetUp.t.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapETHForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountOut);
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountIn);
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);
}

/**
 * @title UniswapV2SwapForkExercise
 * @notice Demonstrates real multi-hop token swap execution against live Uniswap V2 pairs on Ethereum Mainnet.
 * @dev WARNING: This test file ONLY works on a Mainnet fork environment!
 *
 * Running without `--fork-url mainnet` will fail because the token addresses (WETH, DAI, MKR)
 * and the Uniswap V2 Router exist only on Ethereum Mainnet.
 *
 * Commands to run:
 *   forge test --match-contract UniswapV2SwapForkExercise --fork-url mainnet -vv
 *   forge test --match-test test_SwapExactTokensForTokensForkExercise --fork-url mainnet -vv
 *   forge test --match-test test_SwapTokensForExactTokensForkExercise --fork-url mainnet -vv
 */
contract UniswapV2SwapForkExercise is UniswapV2TestSetUp {
    function setUp() public override {
        super.setUp();

        deal(USER, 100 ether);

        vm.startPrank(USER);
        WETH.deposit{value: 100 ether}();
        WETH.approve(address(router), type(uint256).max);
        vm.stopPrank();
    }

    function test_SwapExactTokensForTokensForkExercise() public {
        address[] memory path = new address[](3);
        path[0] = address(WETH);
        path[1] = address(DAI);
        path[2] = address(MKR);

        uint256 amountIn = 100 ether; // 100 ETH swap for
        uint256 amountOutMin = 1; // 1 MKR

        vm.prank(USER);
        uint256[] memory amounts = IUniswapV2Router01(address(router))
            .swapExactTokensForTokens({
                amountIn: amountIn, amountOutMin: amountOutMin, path: path, to: USER, deadline: block.timestamp
            });

        assertGe(MKR.balanceOf(USER), amountOutMin);

        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
    }

    // function swapExactTokensForTokens(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts) {
    //     amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
    //     require(amounts[amounts.length - 1] >= amountOutMin, "INSUFFICIENT_OUTPUT_AMOUNT");
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
    //     );
    //     _swap(amounts, path, to);
    // }

    // NOTE: Example Walkthrough (swapExactTokensForTokens)
    // --- Inputs ---
    // amountIn = 100e18 (100 WETH)
    // amountOutMin = 1 wei MKR
    // path = [WETH, DAI, MKR]
    // to = USER
    //
    // --- Step 1: Calculate chained amounts ---
    // amounts = getAmountsOut(100 WETH, [WETH, DAI, MKR])
    // WETH [0] : 100000000000000000000 (100 WETH sold)
    // DAI  [1] : 212112946006325010610793 (~212,112.94 DAI intermediate)
    // MKR  [2] : 7665383235499467 (~0.007665 MKR bought)
    //
    // --- Step 2: Slippage check ---
    // require(amounts[2] >= amountOutMin); // 7.665e15 >= 1 wei -> PASS
    //
    // --- Step 3: Pull input token ---
    // TransferHelper.safeTransferFrom(WETH, USER, Pair(WETH, DAI), amounts[0]);
    // Transferred 100 WETH directly to the first pair (WETH/DAI).
    //
    // --- Step 4: _swap(amounts, path, to) Loop ---
    //
    // Loop Hop 0 (i = 0):
    // input = WETH, output = DAI
    // amountOut = amounts[1] = 212112946006325010610793 DAI
    // Destination `to` = Pair(DAI, MKR) (since i < path.length - 2)
    // Pair(WETH, DAI).swap(amount0Out, amount1Out, Pair(DAI, MKR), "");
    // -> DAI is sent directly to Pair(DAI, MKR) (never touches user's wallet!)
    //
    // Loop Hop 1 (i = 1):
    // input = DAI, output = MKR
    // amountOut = amounts[2] = 7665383235499467 MKR
    // Destination `to` = USER (final hop: i == path.length - 2)
    // Pair(DAI, MKR).swap(amount0Out, amount1Out, USER, "");
    // -> MKR is delivered directly to USER!

    function test_SwapTokensForExactTokensForkExercise() public {
        address[] memory path = new address[](3);
        path[0] = address(WETH);
        path[1] = address(DAI);
        path[2] = address(MKR);

        uint256 amountOut = 0.001 ether; // 0.001 MKR (At this time pool has ~0.0076 MKR remaining)
        uint256 amountInMax = 10 ether; // 10 WETH

        vm.prank(USER);
        uint256[] memory amounts = IUniswapV2Router01(address(router))
            .swapTokensForExactTokens({
                amountOut: amountOut, amountInMax: amountInMax, path: path, to: USER, deadline: block.timestamp
            });

        assertGe(MKR.balanceOf(USER), amountOut);

        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);
    }

    // function swapTokensForExactTokens(
    //     uint256 amountOut,
    //     uint256 amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts) {
    //     amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
    //     require(amounts[0] <= amountInMax, "EXCESSIVE_INPUT_AMOUNT");
    //     TransferHelper.safeTransferFrom(
    //         path[0], msg.sender, UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
    //     );
    //     _swap(amounts, path, to);
    // }

    // NOTE: Example Walkthrough (swapTokensForExactTokens)
    // --- Inputs ---
    // amountOut = 0.001e18 (0.001 MKR)
    // amountInMax = 10e18 (10 WETH)
    // path = [WETH, DAI, MKR]
    // to = USER
    //
    // --- Step 1: Calculate required amounts backwards ---
    // amounts = getAmountsIn(0.001 MKR, [WETH, DAI, MKR])
    // WETH [0] : 790045279764009 (~0.000790 WETH required)
    // DAI  [1] : 1762733595058824150 (~1.7627 DAI intermediate)
    // MKR  [2] : 1000000000000000 (0.001 MKR desired)
    //
    // --- Step 2: Slippage check ---
    // require(amounts[0] <= amountInMax); // 7.9e14 <= 10 ether -> PASS
    //
    // --- Step 3: Pull exact input required ---
    // TransferHelper.safeTransferFrom(WETH, USER, Pair(WETH, DAI), amounts[0]);
    // Transferred ~0.000790 WETH directly to Pair(WETH, DAI).
    //
    // --- Step 4: _swap(amounts, path, to) Loop ---
    // (Uses the exact same _swap loop as swapExactTokensForTokens!)
    //
    // Loop Hop 0 (i = 0):
    // Pair(WETH, DAI).swap(amount0Out, amount1Out, Pair(DAI, MKR), "");
    // -> Sends ~1.7627 DAI directly to Pair(DAI, MKR).
    //
    // Loop Hop 1 (i = 1):
    // Pair(DAI, MKR).swap(amount0Out, amount1Out, USER, "");
    // -> Delivers exactly 0.001 MKR to USER!
}
