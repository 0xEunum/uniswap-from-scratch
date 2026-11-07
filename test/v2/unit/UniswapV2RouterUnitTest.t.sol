// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {UniswapV2Router} from "src/v2/UniswapV2Router.sol";
import {UniswapV2Factory} from "src/v2/UniswapV2Factory.sol";
import {UniswapV2Pair} from "src/v2/UniswapV2Pair.sol";

import {UniswapV2HelperConfig} from "script/v2/UniswapV2HelperConfig.s.sol";

import {IUniswapV2Pair} from "src/v2/interfaces/IUniswapV2Pair.sol";
import {IWETH} from "src/v2/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {UniswapV2TestSetUp} from "test/v2/UniswapV2TestSetUp.t.sol";

contract UniswapV2RouterUnitTest is UniswapV2TestSetUp {
    function setUp() public override {
        super.setUp();
    }

    // getAmountIn
    function test_GetAmountIn() public view {
        uint256 reserveIn = 1000 ether;
        uint256 reserveOut = 20_000 ether;

        uint256 amountOut = 2000 ether;

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * FEE_MULTIPLIER;
        uint256 expectedAmountIn = (numerator / denominator) + 1;

        uint256 amountIn = router.getAmountIn(amountOut, reserveIn, reserveOut);

        assertEq(expectedAmountIn, amountIn);
    }

    function test_GetAmountInReverts() public {
        uint256 reserveIn_1 = 0;
        uint256 reserveOut_1 = 0;
        uint256 amountOut_1 = 0;

        uint256 reserveIn_2 = 1000 ether;
        uint256 reserveOut_2 = 20_000 ether;
        uint256 amountOut_2 = 20_000 ether;

        vm.expectRevert(UniswapV2Router.UniswapV2Router__ZeroAmountOut.selector);
        router.getAmountIn(amountOut_1, reserveIn_1, reserveOut_1);

        vm.expectRevert(UniswapV2Router.UniswapV2Router__ZeroReserves.selector);
        router.getAmountIn(amountOut_2, reserveIn_1, reserveOut_1);

        vm.expectRevert(UniswapV2Router.UniswapV2Router__InsufficientOutputReserve.selector);
        router.getAmountIn(amountOut_2, reserveIn_2, reserveOut_2);
    }

    // getAmountOut
    function test_GetAmountOut() public view {
        uint256 reserveIn = 1000 ether;
        uint256 reserveOut = 20_000 ether;

        uint256 amountIn = 100 ether;

        uint256 amountInWithFee = amountIn * FEE_MULTIPLIER;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        uint256 expectedAmountOut = numerator / denominator;

        uint256 amountOut = router.getAmountOut(amountIn, reserveIn, reserveOut);

        assertEq(expectedAmountOut, amountOut);
    }

    function test_GetAmountOutReverts() public {
        uint256 reserveIn_1 = 0;
        uint256 reserveOut_1 = 0;

        uint256 amountIn_1 = 0;

        uint256 reserveIn_2 = 1000 ether;
        uint256 reserveOut_2 = 20_000 ether;

        uint256 amountIn_2 = 100 ether;

        vm.expectRevert(UniswapV2Router.UniswapV2Router__ZeroAmountIn.selector);
        router.getAmountOut(amountIn_1, reserveIn_2, reserveOut_2);

        vm.expectRevert(UniswapV2Router.UniswapV2Router__ZeroReserves.selector);
        router.getAmountOut(amountIn_2, reserveIn_1, reserveOut_1);
    }

    // sortTokens
    function test_SortTokens() public view {
        address tokenA = address(1);
        address tokenB = address(2);

        (address expectedToken0, address expectedToken1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        (address token0, address token1) = router.sortTokens(tokenA, tokenB);

        assertEq(expectedToken0, token0);
        assertEq(expectedToken1, token1);
    }

    function test_SortTokensReverts() public {
        address tokenA = address(1);

        vm.expectRevert(UniswapV2Router.UniswapV2Router__IdenticalAddresses.selector);
        router.sortTokens(tokenA, tokenA);

        vm.expectRevert(UniswapV2Router.UniswapV2Router__ZeroAddress.selector);
        router.sortTokens(tokenA, address(0));
    }

    // pairFor
    function test_PairFor() public view {
        address tokenA = address(1);
        address tokenB = address(2);

        (address token0, address token1) = router.sortTokens(tokenA, tokenB);

        address expectedPairAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            keccak256(type(UniswapV2Pair).creationCode)
                        )
                    )
                )
            )
        );

        address pairAddress = router.pairFor(address(factory), tokenA, tokenB);

        assertEq(pairAddress, expectedPairAddress);
    }

    // quote
    function test_Quote() public view {
        uint256 reserveA = 1000 ether;
        uint256 reserveB = 20_000 ether;

        uint256 amountA = 100 ether;

        uint256 expectedAmountB = (amountA * reserveB) / reserveA;

        uint256 amountB = router.quote(amountA, reserveA, reserveB);

        assertEq(expectedAmountB, amountB);
    }

    function test_QuoteReverts() public {
        uint256 reserveA_1 = 0 ether;
        uint256 reserveB_1 = 0 ether;

        uint256 amountA_1 = 0 ether;

        uint256 reserveA_2 = 1000 ether;
        uint256 reserveB_2 = 20_000 ether;

        uint256 amountA_2 = 100 ether;

        vm.expectRevert(UniswapV2Router.UniswapV2Router__ZeroAmount.selector);
        router.quote(amountA_1, reserveA_2, reserveB_2);

        vm.expectRevert(UniswapV2Router.UniswapV2Router__ZeroReserves.selector);
        router.quote(amountA_2, reserveA_1, reserveB_1);
    }
}
