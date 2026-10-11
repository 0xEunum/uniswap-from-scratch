// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {UniswapV1ExchangeUnitTest} from "./UniswapV1ExchangeUnitTest.t.sol";
import {UniswapV1Exchange} from "src/v1/UniswapV1Exchange.sol";

contract EthToTokenSwapUnitTest is UniswapV1ExchangeUnitTest {
    // getInputPrice

    function test_GetInputPriceCalculatesExpectedAmount() public view {
        uint256 inputAmount = 1 ether;
        uint256 inputReserve = 10 ether;
        uint256 outputReserve = 1_000 ether;

        uint256 inputAmountWithFee = inputAmount * FEE_MULTIPLIER;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * FEE_DENOMINATOR) + inputAmountWithFee;
        uint256 expectedOutputAmount = numerator / denominator;

        uint256 actualOutputAmount = exchange.getInputPrice(inputAmount, inputReserve, outputReserve);

        assertEq(expectedOutputAmount, actualOutputAmount);
    }

    function test_GetInputPriceRevertsWhenInputAmountIsZero() public {
        uint256 inputAmount;
        uint256 inputReserve = 10 ether;
        uint256 outputReserve = 1_000 ether;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroInputAmount.selector);
        exchange.getInputPrice(inputAmount, inputReserve, outputReserve);
    }

    function test_GetInputPriceRevertsWhenInputOrOutputReverseIsZero() public {
        uint256 inputAmount = 1 ether;
        uint256 inputReserve;
        uint256 outputReserve = 1_000 ether;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroReserves.selector);
        exchange.getInputPrice(inputAmount, inputReserve, outputReserve);

        uint256 _inputAmount = 1 ether;
        uint256 _inputReserve = 10 ether;
        uint256 _outputReserve;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroReserves.selector);
        exchange.getInputPrice(_inputAmount, _inputReserve, _outputReserve);
    }

    // getEthToTokenInputPrice
    function test_GetEthToTokenInputPriceReturnsCorrectAmount() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;
        uint256 expectedTokensBought = exchange.getInputPrice(ethSold, 10 ether, 1_000 ether);
        uint256 actualTokensBought = exchange.getEthToTokenInputPrice(ethSold);

        assertEq(expectedTokensBought, actualTokensBought);
    }

    function test_GetEthToTokenInputReverts() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldIsZero.selector);
        exchange.getEthToTokenInputPrice(0);
    }

    // EthToTokenSwapInput
    function test_EthToTokenSwapInput() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;

        uint256 tokenBought = exchange.getEthToTokenInputPrice(ethSold);

        deal(USER, ethSold);

        vm.prank(USER);
        uint256 actualTokensBought = exchange.ethToTokenSwapInput{value: ethSold}(1, block.timestamp);

        assertEq(tokenBought, actualTokensBought);
        assertEq(USER.balance, 0);
        assertEq(address(exchange).balance, ethReserve + ethSold);
        assertEq(token.balanceOf(USER), actualTokensBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve - actualTokensBought);
    }

    function test_EthToTokenRevertsWhenEthSoldIsZero() public {
        uint256 ethSold;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldIsZero.selector);
        exchange.ethToTokenSwapInput{value: ethSold}(1, block.timestamp);
    }

    function test_MinTokenIsZero() public {
        uint256 minToken;
        uint256 ethSold = 1 ether;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensIsZero.selector);
        exchange.ethToTokenSwapInput{value: ethSold}(minToken, block.timestamp);
    }

    function test_MinsTokenIsTooHigh() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;

        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensBought.selector);
        exchange.ethToTokenSwapInput{value: ethSold}(tokensBought + 1, block.timestamp);
    }

    function test_DeadlineIsPassed() public {
        uint256 ethSold = 1 ether;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.ethToTokenSwapInput{value: ethSold}(1, block.timestamp - 1);
    }

    function test_TokensTransferFailed() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 100 ether;
        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        deal(USER, ethSold);

        vm.mockCall(
            address(token), abi.encodeWithSelector(token.transfer.selector, USER, tokensBought), abi.encode(false)
        );

        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector,
                address(exchange),
                USER,
                tokensBought
            )
        );
        exchange.ethToTokenSwapInput{value: ethSold}(1, block.timestamp);
    }
}
