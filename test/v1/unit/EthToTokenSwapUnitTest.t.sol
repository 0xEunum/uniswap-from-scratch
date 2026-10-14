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

    function test_EthToTokenSwapInputEmitsEvent() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;
        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        deal(USER, ethSold);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.TokenPurchase(USER, ethSold, tokensBought);

        vm.prank(USER);
        exchange.ethToTokenSwapInput{value: ethSold}(1, block.timestamp);
    }

    function test_EthToTokenSwapInputRevertsWhenReservesAreZero() public {
        uint256 ethSold = 1 ether;
        deal(USER, ethSold);

        vm.prank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroReserves.selector);
        exchange.ethToTokenSwapInput{value: ethSold}(1, block.timestamp);
    }

    // ethToTokenTransferInput
    function test_EthToTokenTransferInput() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;

        uint256 expectedTokensBought = exchange.getEthToTokenInputPrice(ethSold);

        deal(USER, ethSold);

        vm.prank(USER);
        uint256 actualTokensBought = exchange.ethToTokenTransferInput{value: ethSold}(1, block.timestamp, USER2);

        assertEq(expectedTokensBought, actualTokensBought);
        assertEq(USER.balance, 0);
        assertEq(address(exchange).balance, ethReserve + ethSold);
        assertEq(token.balanceOf(USER), 0);
        assertEq(token.balanceOf(USER2), actualTokensBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve - actualTokensBought);
    }

    function test_EthToTokenTransferInputEmitsEvent() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethSold = 1 ether;
        uint256 tokensBought = exchange.getEthToTokenInputPrice(ethSold);

        deal(USER, ethSold);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.TokenPurchase(USER, ethSold, tokensBought);

        vm.prank(USER);
        exchange.ethToTokenTransferInput{value: ethSold}(1, block.timestamp, USER2);
    }

    function test_EthToTokenTransferInputRevertsWhenRecipientIsZeroAddress() public {
        uint256 ethSold = 1 ether;
        deal(USER, ethSold);

        vm.prank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferInput{value: ethSold}(1, block.timestamp, address(0));
    }

    function test_EthToTokenTransferInputRevertsWhenRecipientIsExchange() public {
        uint256 ethSold = 1 ether;
        deal(USER, ethSold);

        vm.prank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferInput{value: ethSold}(1, block.timestamp, address(exchange));
    }

    // getOutputPrice
    function test_GetOutputPriceReturnsExpectedAmount() public view {
        uint256 outputAmount = 100 ether;
        uint256 inputReserve = 10 ether;
        uint256 outputReserve = 1_000 ether;

        uint256 numerator = inputReserve * outputAmount * FEE_DENOMINATOR;
        uint256 denominator = (outputReserve - outputAmount) * FEE_MULTIPLIER;
        uint256 expectedInputAmount = (numerator / denominator) + 1;

        uint256 actualInputAmount = exchange.getOutputPrice(outputAmount, inputReserve, outputReserve);

        assertEq(expectedInputAmount, actualInputAmount);
    }

    function test_RevertWhenOutputAmountIsZero() public {
        uint256 outputAmount;
        uint256 inputReserve = 10 ether;
        uint256 outputReserve = 1_000 ether;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroOutputAmount.selector);
        exchange.getOutputPrice(outputAmount, inputReserve, outputReserve);
    }

    function test_RevertWhenInputAndOutputReserveIsZero() public {
        uint256 outputAmount = 100 ether;
        uint256 inputReserve;
        uint256 outputReserve = 1_000 ether;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroReserves.selector);
        exchange.getOutputPrice(outputAmount, inputReserve, outputReserve);

        uint256 _outputAmount = 100 ether;
        uint256 _inputReserve = 10 ether;
        uint256 _outputReserve;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroReserves.selector);
        exchange.getOutputPrice(_outputAmount, _inputReserve, _outputReserve);
    }

    function test_RevertWhenOutputAmountIsGreaterThanOutputReserve() public {
        uint256 outputAmount = 100 ether;
        uint256 inputReserve = 10 ether;
        uint256 outputReserve = 1_0 ether;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientOutputReserve.selector);
        exchange.getOutputPrice(outputAmount, inputReserve, outputReserve);
    }

    //getEthToTokenOutputPrice

    function test_GetEthToTokenOutputPrice() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 expectedEthSold = exchange.getOutputPrice(tokensBought, 10 ether, 1_000 ether);
        uint256 actualEthSold = exchange.getEthToTokenOutputPrice(tokensBought);
        assertEq(expectedEthSold, actualEthSold);
    }

    function test_RevertsWhenTokensBoughtIsZero() public {
        uint256 tokensBought;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchange.getEthToTokenOutputPrice(tokensBought);
    }

    //ethToTokenSwapOutput

    function test_EthToTokenSwapOutput() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 tokensBought = 10 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        deal(USER, ethSold);

        vm.prank(USER);
        uint256 actualEthSold = exchange.ethToTokenSwapOutput{value: ethSold}(tokensBought, block.timestamp);

        assertEq(actualEthSold, ethSold);
        assertEq(token.balanceOf(USER), tokensBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve - tokensBought);
        assertEq(USER.balance, 0);
        assertEq(address(exchange).balance, ethSold + ethReserve);
    }

    function test_RefundsUnusedEth() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);
        uint256 maxEth = ethSold + 1 ether;

        deal(USER, maxEth);

        vm.prank(USER);
        exchange.ethToTokenSwapOutput{value: maxEth}(tokensBought, block.timestamp);

        assertEq(USER.balance, 1 ether);
    }

    function test_RevertWhenTokensBoughtIsZero() public {
        uint256 tokensBought;
        uint256 ethSold = 10 ether;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchange.ethToTokenSwapOutput{value: ethSold}(tokensBought, block.timestamp);
    }

    function test_RevertsWhenMaxEthIsZero() public {
        uint256 tokensBought = 100 ether;

        uint256 maxEth;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxEthIsZero.selector);
        exchange.ethToTokenSwapOutput{value: maxEth}(tokensBought, block.timestamp);
    }

    function test_RevertsWhenEthSoldIsGreaterThanMaxEth() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldExceedsMaxEth.selector);
        exchange.ethToTokenSwapOutput{value: ethSold - 1 ether}(tokensBought, block.timestamp);
    }

    function test_RevertsIfDeadlinePassed() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.ethToTokenSwapOutput{value: 1 ether}(100 ether, block.timestamp - 1);
    }

    //ethToTokenTransferOutput

    function test_EthToTokenTransferOutput() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 ethReserve = 10 ether;
        uint256 tokensReserve = 1_000 ether;

        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        deal(USER, ethSold);

        vm.prank(USER);
        uint256 actualEthSold = exchange.ethToTokenTransferOutput{value: ethSold}(tokensBought, block.timestamp, USER2);

        assertEq(actualEthSold, ethSold);
        assertEq(token.balanceOf(USER2), tokensBought);
        assertEq(token.balanceOf(USER), 0);
        assertEq(token.balanceOf(address(exchange)), tokensReserve - tokensBought);
        assertEq(USER.balance, 0);
        assertEq(address(exchange).balance, ethReserve + ethSold);
    }

    function test_RefundUnusedEth() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        uint256 maxEth = ethSold + 1 ether;

        deal(USER, maxEth);

        vm.prank(USER);
        exchange.ethToTokenTransferOutput{value: maxEth}(tokensBought, block.timestamp, USER2);

        assertEq(USER.balance, 1 ether);
        assertEq(token.balanceOf(USER2), tokensBought);
    }

    function test_GetEthToTokenOutputPriceRevertsWhenReservesAreZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroReserves.selector);
        exchange.getEthToTokenOutputPrice(10 ether);
    }

    function test_EthToTokenSwapOutputEmitsEvent() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        deal(USER, ethSold);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.TokenPurchase(USER, ethSold, tokensBought);

        vm.prank(USER);
        exchange.ethToTokenSwapOutput{value: ethSold}(tokensBought, block.timestamp);
    }

    function test_EthToTokenSwapOutputTokensTransferFailed() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

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
        exchange.ethToTokenSwapOutput{value: ethSold}(tokensBought, block.timestamp);
    }

    function test_EthToTokenSwapOutputEthTransferFailed() public addFakeLiquidity(10 ether, 1_000 ether) {
        RejectEther rejecter = new RejectEther();
        uint256 tokensBought = 100 ether;
        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);
        uint256 maxEth = ethSold + 1 ether;

        deal(address(rejecter), maxEth);

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__EthTransferFailed.selector, address(rejecter), 1 ether
            )
        );
        rejecter.swap(exchange, tokensBought, maxEth);
    }

    function test_EthToTokenTransferOutputEmitsEvent() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensBought = 100 ether;
        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        deal(USER, ethSold);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.TokenPurchase(USER, ethSold, tokensBought);

        vm.prank(USER);
        exchange.ethToTokenTransferOutput{value: ethSold}(tokensBought, block.timestamp, USER2);
    }

    function test_EthToTokenTransferOutputRevertsWhenRecipientIsZeroAddress() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferOutput{value: 1 ether}(100 ether, block.timestamp, address(0));
    }

    function test_EthToTokenTransferOutputRevertsWhenRecipientIsExchange() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.ethToTokenTransferOutput{value: 1 ether}(100 ether, block.timestamp, address(exchange));
    }

    function test_EthToTokenTransferOutputRevertsIfDeadlinePassed() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.ethToTokenTransferOutput{value: 1 ether}(100 ether, block.timestamp - 1, USER2);
    }

    function test_EthToTokenTransferOutputRevertsWhenTokensBoughtIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchange.ethToTokenTransferOutput{value: 1 ether}(0, block.timestamp, USER2);
    }

    function test_EthToTokenTransferOutputRevertsWhenMaxEthIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxEthIsZero.selector);
        exchange.ethToTokenTransferOutput{value: 0}(100 ether, block.timestamp, USER2);
    }

    function test_EthToTokenTransferOutputRevertsWhenEthSoldIsGreaterThanMaxEth()
        public
        addFakeLiquidity(10 ether, 1_000 ether)
    {
        uint256 tokensBought = 100 ether;
        uint256 ethSold = exchange.getEthToTokenOutputPrice(tokensBought);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthSoldExceedsMaxEth.selector);
        exchange.ethToTokenTransferOutput{value: ethSold - 1 ether}(tokensBought, block.timestamp, USER2);
    }
}

contract RejectEther {
    function swap(UniswapV1Exchange _exchange, uint256 _tokensBought, uint256 _maxEth) external {
        _exchange.ethToTokenSwapOutput{value: _maxEth}(_tokensBought, block.timestamp);
    }
}
