// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {UniswapV1ExchangeUnitTest} from "./UniswapV1ExchangeUnitTest.t.sol";
import {UniswapV1Exchange} from "src/v1/UniswapV1Exchange.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TokenToEthSwapUnitTest is UniswapV1ExchangeUnitTest {
    // getTokenToEthInputPrice

    function test_GetTokenToEthInputPrice() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 1_000 ether;

        uint256 expectedEthBought = exchange.getInputPrice(tokensSold, 1_000 ether, 10 ether);
        uint256 actualEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        assertEq(expectedEthBought, actualEthBought);
    }

    function test_RevertsWhenTokensSoldIsZero() public {
        uint256 tokensSold = 0;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);
        exchange.getTokenToEthInputPrice(tokensSold);
    }

    // tokenToEthSwapInput

    function test_TokenToEthSwapInput() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 tokensSold = 100 ether;

        deal(address(token), USER, tokensSold);

        uint256 expectedEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        uint256 actualEthBought = exchange.tokenToEthSwapInput(tokensSold, 1, block.timestamp);
        vm.stopPrank();

        assertEq(actualEthBought, expectedEthBought);
        assertEq(address(exchange).balance, ethReserve - expectedEthBought);
        assertEq(USER.balance, expectedEthBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + tokensSold);
        assertEq(token.balanceOf(USER), 0);
    }

    function test_TokenToEthSwapInputEmitsEvent() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        deal(address(token), USER, tokensSold);

        uint256 expectedEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.EthPurchase(USER, tokensSold, expectedEthBought);

        exchange.tokenToEthSwapInput(tokensSold, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_TokenToEthSwapInputRevertsWhenTokensSoldIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);
        exchange.tokenToEthSwapInput(0, 1, block.timestamp);
    }

    function test_TokenToEthSwapInputRevertsWhenMinEthIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthIsZero.selector);
        exchange.tokenToEthSwapInput(100 ether, 0, block.timestamp);
    }

    function test_TokenToEthSwapInputRevertsWhenMinEthTooHigh() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        uint256 expectedEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        deal(address(token), USER, tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtExceedsMinEth.selector);
        exchange.tokenToEthSwapInput(tokensSold, expectedEthBought + 1, block.timestamp);
        vm.stopPrank();
    }

    function test_TokenToEthSwapInputRevertsWhenDeadlinePassed() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        deal(address(token), USER, tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.tokenToEthSwapInput(tokensSold, 1, block.timestamp - 1);
        vm.stopPrank();
    }

    function test_TokenToEthSwapInputRevertsWhenTokenTransferFails() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        deal(address(token), USER, tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transferFrom.selector, USER, address(exchange), tokensSold),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector, USER, address(exchange), tokensSold
            )
        );
        exchange.tokenToEthSwapInput(tokensSold, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_TokenToEthSwapInputRevertsWhenEthTransferFails() public addFakeLiquidity(10 ether, 1_000 ether) {
        RejectEtherBuyer rejecter = new RejectEtherBuyer();
        uint256 tokensSold = 100 ether;
        token.mint(address(rejecter), tokensSold);

        uint256 expectedEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__EthTransferFailed.selector, address(rejecter), expectedEthBought
            )
        );
        rejecter.swapInput(exchange, token, tokensSold, 1);
    }

    // tokenToEthTransferInput

    function test_TokenToEthTransferInput() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 tokensSold = 100 ether;

        deal(address(token), USER, tokensSold);

        uint256 expectedEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        uint256 actualEthBought = exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp, USER2);
        vm.stopPrank();

        assertEq(actualEthBought, expectedEthBought);
        assertEq(address(exchange).balance, ethReserve - expectedEthBought);
        assertEq(USER.balance, 0);
        assertEq(USER2.balance, expectedEthBought);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + tokensSold);
        assertEq(token.balanceOf(USER), 0);
    }

    function test_TokenToEthTransferInputEmitsEvent() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        deal(address(token), USER, tokensSold);

        uint256 expectedEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.EthPurchase(USER, tokensSold, expectedEthBought);

        exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp, USER2);
        vm.stopPrank();
    }

    function test_TokenToEthTransferInputRevertsWhenRecipientIsZeroAddress() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferInput(100 ether, 1, block.timestamp, address(0));
    }

    function test_TokenToEthTransferInputRevertsWhenRecipientIsExchange() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferInput(100 ether, 1, block.timestamp, address(exchange));
    }

    function test_TokenToEthTransferInputRevertsWhenTokensSoldIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);
        exchange.tokenToEthTransferInput(0, 1, block.timestamp, USER2);
    }

    function test_TokenToEthTransferInputRevertsWhenMinEthIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthIsZero.selector);
        exchange.tokenToEthTransferInput(100 ether, 0, block.timestamp, USER2);
    }

    function test_TokenToEthTransferInputRevertsWhenMinEthTooHigh() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        uint256 expectedEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        deal(address(token), USER, tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtExceedsMinEth.selector);
        exchange.tokenToEthTransferInput(tokensSold, expectedEthBought + 1, block.timestamp, USER2);
        vm.stopPrank();
    }

    function test_TokenToEthTransferInputRevertsWhenDeadlinePassed() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 tokensSold = 100 ether;
        deal(address(token), USER, tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp - 1, USER2);
        vm.stopPrank();
    }

    function test_TokenToEthTransferInputRevertsWhenTokenTransferFails()
        public
        addFakeLiquidity(10 ether, 1_000 ether)
    {
        uint256 tokensSold = 100 ether;
        deal(address(token), USER, tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transferFrom.selector, USER, address(exchange), tokensSold),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector, USER, address(exchange), tokensSold
            )
        );
        exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp, USER2);
        vm.stopPrank();
    }

    function test_TokenToEthTransferInputRevertsWhenEthTransferFails() public addFakeLiquidity(10 ether, 1_000 ether) {
        RejectEtherRecipient rejecter = new RejectEtherRecipient();
        uint256 tokensSold = 100 ether;
        deal(address(token), USER, tokensSold);

        uint256 expectedEthBought = exchange.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), tokensSold);

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__EthTransferFailed.selector, address(rejecter), expectedEthBought
            )
        );
        exchange.tokenToEthTransferInput(tokensSold, 1, block.timestamp, address(rejecter));
        vm.stopPrank();
    }

    // getTokenToEthOutputPrice

    function test_GetTokenToEthOutputPrice() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethBought = 1 ether;

        uint256 expectedTokensSold = exchange.getOutputPrice(ethBought, 1_000 ether, 10 ether);
        uint256 actualTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        assertEq(expectedTokensSold, actualTokensSold);
    }

    function test_GetTokenToEthOutputPriceRevertsWhenEthBoughtIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtIsZero.selector);
        exchange.getTokenToEthOutputPrice(0);
    }

    // tokenToEthSwapOutput

    function test_TokenToEthSwapOutput() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 ethBought = 1 ether;

        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        uint256 actualTokensSold = exchange.tokenToEthSwapOutput(ethBought, expectedTokensSold, block.timestamp);
        vm.stopPrank();

        assertEq(actualTokensSold, expectedTokensSold);
        assertEq(USER.balance, ethBought);
        assertEq(address(exchange).balance, ethReserve - ethBought);
        assertEq(token.balanceOf(USER), 0);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + expectedTokensSold);
    }

    function test_TokenToEthSwapOutputEmitsEvent() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.EthPurchase(USER, expectedTokensSold, ethBought);

        exchange.tokenToEthSwapOutput(ethBought, expectedTokensSold, block.timestamp);
        vm.stopPrank();
    }

    function test_TokenToEthSwapOutputRevertsWhenEthBoughtIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtIsZero.selector);
        exchange.tokenToEthSwapOutput(0, 1_000 ether, block.timestamp);
    }

    function test_TokenToEthSwapOutputRevertsWhenTokensSoldExceedsMaxTokens()
        public
        addFakeLiquidity(10 ether, 1_000 ether)
    {
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldExceedsMaxTokens.selector);
        exchange.tokenToEthSwapOutput(ethBought, expectedTokensSold - 1, block.timestamp);
        vm.stopPrank();
    }

    function test_TokenToEthSwapOutputRevertsWhenDeadlinePassed() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.tokenToEthSwapOutput(ethBought, expectedTokensSold, block.timestamp - 1);
        vm.stopPrank();
    }

    function test_TokenToEthSwapOutputRevertsWhenTokenTransferFails() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transferFrom.selector, USER, address(exchange), expectedTokensSold),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector,
                USER,
                address(exchange),
                expectedTokensSold
            )
        );
        exchange.tokenToEthSwapOutput(ethBought, expectedTokensSold, block.timestamp);
        vm.stopPrank();
    }

    function test_TokenToEthSwapOutputRevertsWhenEthTransferFails() public addFakeLiquidity(10 ether, 1_000 ether) {
        RejectEtherBuyer rejecter = new RejectEtherBuyer();
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        token.mint(address(rejecter), expectedTokensSold);

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__EthTransferFailed.selector, address(rejecter), ethBought
            )
        );
        rejecter.swapOutput(exchange, token, ethBought, expectedTokensSold);
    }

    // tokenToEthTransferOutput

    function test_TokenToEthTransferOutput() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethReserve = 10 ether;
        uint256 tokenReserve = 1_000 ether;
        uint256 ethBought = 1 ether;

        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        uint256 actualTokensSold =
            exchange.tokenToEthTransferOutput(ethBought, expectedTokensSold, block.timestamp, USER2);
        vm.stopPrank();

        assertEq(actualTokensSold, expectedTokensSold);
        assertEq(USER.balance, 0);
        assertEq(USER2.balance, ethBought);
        assertEq(address(exchange).balance, ethReserve - ethBought);
        assertEq(token.balanceOf(USER), 0);
        assertEq(token.balanceOf(address(exchange)), tokenReserve + expectedTokensSold);
    }

    function test_TokenToEthTransferOutputEmitsEvent() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.EthPurchase(USER, expectedTokensSold, ethBought);

        exchange.tokenToEthTransferOutput(ethBought, expectedTokensSold, block.timestamp, USER2);
        vm.stopPrank();
    }

    function test_TokenToEthTransferOutputRevertsWhenRecipientIsZeroAddress() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferOutput(1 ether, 100 ether, block.timestamp, address(0));
    }

    function test_TokenToEthTransferOutputRevertsWhenRecipientIsExchange() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchange.tokenToEthTransferOutput(1 ether, 100 ether, block.timestamp, address(exchange));
    }

    function test_TokenToEthTransferOutputRevertsWhenEthBoughtIsZero() public {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtIsZero.selector);
        exchange.tokenToEthTransferOutput(0, 100 ether, block.timestamp, USER2);
    }

    function test_TokenToEthTransferOutputRevertsWhenTokensSoldExceedsMaxTokens()
        public
        addFakeLiquidity(10 ether, 1_000 ether)
    {
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldExceedsMaxTokens.selector);
        exchange.tokenToEthTransferOutput(ethBought, expectedTokensSold - 1, block.timestamp, USER2);
        vm.stopPrank();
    }

    function test_TokenToEthTransferOutputRevertsWhenDeadlinePassed() public addFakeLiquidity(10 ether, 1_000 ether) {
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.tokenToEthTransferOutput(ethBought, expectedTokensSold, block.timestamp - 1, USER2);
        vm.stopPrank();
    }

    function test_TokenToEthTransferOutputRevertsWhenTokenTransferFails()
        public
        addFakeLiquidity(10 ether, 1_000 ether)
    {
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transferFrom.selector, USER, address(exchange), expectedTokensSold),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector,
                USER,
                address(exchange),
                expectedTokensSold
            )
        );
        exchange.tokenToEthTransferOutput(ethBought, expectedTokensSold, block.timestamp, USER2);
        vm.stopPrank();
    }

    function test_TokenToEthTransferOutputRevertsWhenEthTransferFails() public addFakeLiquidity(10 ether, 1_000 ether) {
        RejectEtherRecipient rejecter = new RejectEtherRecipient();
        uint256 ethBought = 1 ether;
        uint256 expectedTokensSold = exchange.getTokenToEthOutputPrice(ethBought);

        deal(address(token), USER, expectedTokensSold);

        vm.startPrank(USER);
        token.approve(address(exchange), expectedTokensSold);

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__EthTransferFailed.selector, address(rejecter), ethBought
            )
        );
        exchange.tokenToEthTransferOutput(ethBought, expectedTokensSold, block.timestamp, address(rejecter));
        vm.stopPrank();
    }
}

// Helper contracts

contract RejectEtherRecipient {
    // Empty contract that rejects receiving ETH
}

contract RejectEtherBuyer {
    function swapInput(UniswapV1Exchange _exchange, ERC20Mock _token, uint256 _tokensSold, uint256 _minEth) external {
        _token.approve(address(_exchange), _tokensSold);
        _exchange.tokenToEthSwapInput(_tokensSold, _minEth, block.timestamp);
    }

    function swapOutput(UniswapV1Exchange _exchange, ERC20Mock _token, uint256 _ethBought, uint256 _maxTokens)
        external
    {
        _token.approve(address(_exchange), _maxTokens);
        _exchange.tokenToEthSwapOutput(_ethBought, _maxTokens, block.timestamp);
    }
}
