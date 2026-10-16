// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {UniswapV1Exchange} from "src/v1/UniswapV1Exchange.sol";
import {UniswapV1ExchangeUnitTest} from "./UniswapV1ExchangeUnitTest.t.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract LiquidityProvidingUnitTest is UniswapV1ExchangeUnitTest {
    modifier addInitialLiquidity(uint256 _minLpTokens, uint256 _ethAmount, uint256 _tokenAmount) {
        deal(address(token), USER, _tokenAmount);
        deal(USER, _ethAmount);

        vm.startPrank(USER);
        token.approve(address(exchange), _tokenAmount);

        exchange.addLiquidity{value: _ethAmount}(_minLpTokens, _tokenAmount, block.timestamp);
        vm.stopPrank();
        _;
    }

    function addMoreLiquidity(uint256 _minLpTokens, uint256 _ethAmount, uint256 _tokenAmount)
        private
        returns (uint256)
    {
        deal(address(token), USER, _tokenAmount);
        deal(USER, _ethAmount);

        vm.startPrank(USER);
        token.approve(address(exchange), _tokenAmount);

        uint256 liquidityMinted = exchange.addLiquidity{value: _ethAmount}(_minLpTokens, _tokenAmount, block.timestamp);
        return liquidityMinted;
    }

    // addLiquidity
    function test_InitialAddLiquidity() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        assertEq(USER.balance, 0);
        assertEq(token.balanceOf(USER), 0);

        assertEq(address(exchange).balance, 10 ether);
        assertEq(token.balanceOf(address(exchange)), 1_000 ether);

        assertEq(exchange.totalSupply(), 10 ether);
        assertEq(exchange.balanceOf(USER), 10 ether);
    }

    function test_InitialAddLiquiditySucceedsWithExactOneGwei() public {
        uint256 ethAmount = 1 gwei; // exactly 1_000_000_000 wei
        uint256 tokenAmount = 100 ether;

        deal(address(token), USER, tokenAmount);
        deal(USER, ethAmount);

        vm.startPrank(USER);
        token.approve(address(exchange), tokenAmount);

        uint256 liquidityMinted = exchange.addLiquidity{value: ethAmount}(0, tokenAmount, block.timestamp);
        vm.stopPrank();

        assertEq(liquidityMinted, 1 gwei);
        assertEq(exchange.totalSupply(), 1 gwei);
        assertEq(exchange.balanceOf(USER), 1 gwei);
    }

    function test_InitialAddLiquidityEmitsEvent() public {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 1_000 ether;

        deal(address(token), USER, tokenAmount);
        deal(USER, ethAmount);

        vm.startPrank(USER);
        token.approve(address(exchange), tokenAmount);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.AddLiquidity(USER, ethAmount, tokenAmount);

        exchange.addLiquidity{value: ethAmount}(0, tokenAmount, block.timestamp);
        vm.stopPrank();
    }

    function test_InitialAddLiquidityRevertsWhenTokenTransferFails() public {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 1_000 ether;

        deal(address(token), USER, tokenAmount);
        deal(USER, ethAmount);

        vm.startPrank(USER);
        token.approve(address(exchange), tokenAmount);

        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transferFrom.selector, USER, address(exchange), tokenAmount),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector, USER, address(exchange), tokenAmount
            )
        );
        exchange.addLiquidity{value: ethAmount}(0, tokenAmount, block.timestamp);
        vm.stopPrank();
    }

    function test_RevertsWhenDeadlineIsExpired() public {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 1_000 ether;
        uint256 minLpTokens = 0;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.addLiquidity{value: ethAmount}(minLpTokens, tokenAmount, block.timestamp - 1);
    }

    function test_RevertsWhenMaxTokensIsZero() public {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 0;
        uint256 minLpTokens = 0;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxTokensIsZero.selector);
        exchange.addLiquidity{value: ethAmount}(minLpTokens, tokenAmount, block.timestamp);
    }

    function test_RevertsWhenEthSentIsZero() public {
        uint256 ethAmount = 0;
        uint256 tokenAmount = 1_000 ether;
        uint256 minLpTokens = 0;

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthAmount.selector);
        exchange.addLiquidity{value: ethAmount}(minLpTokens, tokenAmount, block.timestamp);
    }

    function test_RevertsWhenSentLessThanOneGweiInitialLiquidity() public {
        uint256 ethAmount = 1 gwei - 1; // 999_999_999 wei < 1_000_000_000
        uint256 tokenAmount = 1_000 ether;

        deal(address(token), USER, tokenAmount);
        deal(USER, ethAmount);

        vm.startPrank(USER);
        token.approve(address(exchange), tokenAmount);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthAmount.selector);
        exchange.addLiquidity{value: ethAmount}(0, tokenAmount, block.timestamp);
        vm.stopPrank();
    }

    function test_SecondProviderMintsProportionalLiquidity() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        uint256 ethAmountLp2 = 1 ether;
        uint256 tokenAmountLp2 = 200 ether;

        deal(address(token), USER2, tokenAmountLp2);
        deal(USER2, ethAmountLp2);

        vm.startPrank(USER2);
        token.approve(address(exchange), tokenAmountLp2);

        uint256 liquidityMinted =
            exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2, tokenAmountLp2, block.timestamp);
        vm.stopPrank();

        // tokenAmount = 1 ether * 1_000 ether / 10 ether + 1 = 100 ether + 1
        uint256 expectedTokenAmount = 100 ether + 1;
        assertEq(liquidityMinted, 1 ether);
        assertEq(exchange.totalSupply(), 11 ether);
        assertEq(exchange.balanceOf(USER), 10 ether);
        assertEq(exchange.balanceOf(USER2), 1 ether);
        assertEq(address(exchange).balance, 11 ether);
        assertEq(token.balanceOf(address(exchange)), 1_000 ether + expectedTokenAmount);
        assertEq(token.balanceOf(USER2), tokenAmountLp2 - expectedTokenAmount);
    }

    function test_SecondProviderAddLiquidityEmitsEvent() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        uint256 ethAmountLp2 = 1 ether;
        uint256 tokenAmountLp2 = 200 ether;
        uint256 expectedTokenAmount = 100 ether + 1;

        deal(address(token), USER2, tokenAmountLp2);
        deal(USER2, ethAmountLp2);

        vm.startPrank(USER2);
        token.approve(address(exchange), tokenAmountLp2);

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.AddLiquidity(USER2, ethAmountLp2, expectedTokenAmount);

        exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2, tokenAmountLp2, block.timestamp);
        vm.stopPrank();
    }

    function test_SecondProviderRevertsWhenTokenTransferFails() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        uint256 ethAmountLp2 = 1 ether;
        uint256 tokenAmountLp2 = 200 ether;
        uint256 expectedTokenAmount = 100 ether + 1;

        deal(address(token), USER2, tokenAmountLp2);
        deal(USER2, ethAmountLp2);

        vm.startPrank(USER2);
        token.approve(address(exchange), tokenAmountLp2);

        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transferFrom.selector, USER2, address(exchange), expectedTokenAmount),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector,
                USER2,
                address(exchange),
                expectedTokenAmount
            )
        );
        exchange.addLiquidity{value: ethAmountLp2}(ethAmountLp2, tokenAmountLp2, block.timestamp);
        vm.stopPrank();
    }

    function test_RevertsWhenMinLiquidityIsZero() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 1_000 ether;
        uint256 minLpTokens = 0;

        deal(address(token), USER2, tokenAmount);
        deal(USER2, ethAmount);

        vm.prank(USER2);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinLiquidityIsZero.selector);
        exchange.addLiquidity{value: ethAmount}(minLpTokens, tokenAmount, block.timestamp);
    }

    function test_RevertsWhenMaxTokensExceeded() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        uint256 _ethAmount = 1 ether;
        uint256 _tokenAmount = 100 ether;

        deal(address(token), USER2, _tokenAmount);
        deal(USER2, _ethAmount);

        vm.startPrank(USER2);
        token.approve(address(exchange), _tokenAmount);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxTokensExceeded.selector);
        exchange.addLiquidity{value: _ethAmount}(_ethAmount, _tokenAmount, block.timestamp);
        vm.stopPrank();
    }

    function test_RevertsWhenInsufficientLiquidityMinted() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        uint256 _ethAmount = 1 ether;
        uint256 _tokenAmount = 1000 ether;
        uint256 minLpTokens = 1 ether;

        deal(address(token), USER2, _tokenAmount);
        deal(USER2, _ethAmount);

        vm.startPrank(USER2);
        token.approve(address(exchange), _tokenAmount);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientLiquidityMinted.selector);
        exchange.addLiquidity{value: _ethAmount}(minLpTokens + 1, _tokenAmount, block.timestamp);
        vm.stopPrank();
    }

    function test_LpTokensCanBeTransferred() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        vm.prank(USER);
        exchange.transfer(USER2, 1 ether);

        assertEq(exchange.balanceOf(USER), 9 ether);
        assertEq(exchange.balanceOf(USER2), 1 ether);
    }

    function test_LpTokenTransferRevertsIfAmountExceedsBalance() public addInitialLiquidity(0, 10 ether, 1_000 ether) {
        uint256 USERLiquidity = exchange.balanceOf(USER);

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, USER, USERLiquidity, USERLiquidity + 1
            )
        );
        exchange.transfer(USER2, USERLiquidity + 1);
        vm.stopPrank();
    }

    // removeLiquidity
    function test_RemoveLiquidity() public addInitialLiquidity(0, 10 ether, 20_000 ether) {
        uint256 initialEthReserve = 10 ether;
        uint256 initialTokenReserve = 20_000 ether;

        uint256 liquidityToBurn = 1 ether; // 10% off the total pool reserve.

        uint256 expectedEthAmount = 1 ether;
        uint256 expectedTokenAmount = 2000 ether;

        uint256 USEREthBefore = USER.balance;
        uint256 USERTokenBefore = token.balanceOf(USER);

        vm.prank(USER);
        (uint256 ethAmount, uint256 tokenAmount) =
            exchange.removeLiquidity(liquidityToBurn, expectedEthAmount, expectedTokenAmount, block.timestamp);

        assertEq(ethAmount, expectedEthAmount);
        assertEq(tokenAmount, expectedTokenAmount);

        assertEq(USER.balance, USEREthBefore + ethAmount);
        assertEq(token.balanceOf(USER), USERTokenBefore + tokenAmount);

        assertEq(address(exchange).balance, initialEthReserve - ethAmount);
        assertEq(token.balanceOf(address(exchange)), initialTokenReserve - tokenAmount);

        assertEq(exchange.balanceOf(USER), 9 ether);
        assertEq(exchange.totalSupply(), 9 ether);
    }

    function test_RemoveLiquidityRevertsIfAmountIsZero() external addInitialLiquidity(0, 10 ether, 20_000 ether) {
        vm.startPrank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__AmountIsZero.selector);
        exchange.removeLiquidity(0, 1, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfDeadlineExpired() external addInitialLiquidity(0, 10 ether, 20_000 ether) {
        vm.startPrank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchange.removeLiquidity(1 ether, 1, 1, block.timestamp - 1);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfMinEthIsZero() external addInitialLiquidity(0, 10 ether, 20_000 ether) {
        vm.startPrank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthIsZero.selector);
        exchange.removeLiquidity(1 ether, 0, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfMinTokensIsZero() external addInitialLiquidity(0, 10 ether, 20_000 ether) {
        vm.startPrank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensIsZero.selector);
        exchange.removeLiquidity(1 ether, 1, 0, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfInsufficientEthWithdrawn()
        external
        addInitialLiquidity(0, 10 ether, 20_000 ether)
    {
        vm.startPrank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthWithdrawn.selector);
        exchange.removeLiquidity(1 ether, 1 ether + 1, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfInsufficientTokensWithdrawn()
        external
        addInitialLiquidity(0, 10 ether, 20_000 ether)
    {
        vm.startPrank(USER);
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensWithdrawn.selector);
        exchange.removeLiquidity(1 ether, 1, 2_000 ether + 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfUserHasInsufficientLpBalance()
        external
        addInitialLiquidity(0, 10 ether, 20_000 ether)
    {
        uint256 USERLiquidity = exchange.balanceOf(USER);

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, USER, USERLiquidity, USERLiquidity + 1
            )
        );
        exchange.removeLiquidity(USERLiquidity + 1, 1, 1, block.timestamp);
        vm.stopPrank();
    }

    function test_RemoveLiquidityRevertsIfTotalLiquidityIsZero() external {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TotalLiquidityIsZero.selector);
        exchange.removeLiquidity(1 ether, 1, 1, block.timestamp);
    }

    function test_RemoveLiquidityEmitsEvent() external addInitialLiquidity(0, 10 ether, 20_000 ether) {
        uint256 liquidityToBurn = 1 ether;
        uint256 expectedEthAmount = 1 ether;
        uint256 expectedTokenAmount = 2_000 ether;

        vm.expectEmit(true, false, false, true, address(exchange));
        emit UniswapV1Exchange.RemoveLiquidity(USER, expectedEthAmount, expectedTokenAmount);

        vm.prank(USER);
        exchange.removeLiquidity(liquidityToBurn, expectedEthAmount, expectedTokenAmount, block.timestamp);
    }

    function test_RemoveLiquidityRevertsIfTokenTransferFails() external addInitialLiquidity(0, 10 ether, 20_000 ether) {
        uint256 liquidityToBurn = 1 ether;
        uint256 expectedTokenAmount = 2_000 ether;

        vm.mockCall(
            address(token),
            abi.encodeWithSelector(token.transfer.selector, USER, expectedTokenAmount),
            abi.encode(false)
        );

        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector,
                address(exchange),
                USER,
                expectedTokenAmount
            )
        );
        exchange.removeLiquidity(liquidityToBurn, 1, 1, block.timestamp);
    }

    function test_RemoveLiquidityRevertsIfEthTransferFails() external addInitialLiquidity(0, 10 ether, 20_000 ether) {
        RejectRemoveLiquidityEther rejecter = new RejectRemoveLiquidityEther();

        vm.prank(USER);
        exchange.transfer(address(rejecter), 1 ether);

        uint256 expectedEthAmount = 1 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__EthTransferFailed.selector, address(rejecter), expectedEthAmount
            )
        );
        rejecter.remove(exchange, 1 ether);
    }
}

contract RejectRemoveLiquidityEther {
    function remove(UniswapV1Exchange _exchange, uint256 _amount) external {
        _exchange.removeLiquidity(_amount, 1, 1, block.timestamp);
    }
}
