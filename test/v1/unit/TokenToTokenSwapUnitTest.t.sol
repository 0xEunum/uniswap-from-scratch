// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/v1/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/v1/UniswapV1Factory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TokenToTokenSwapUnitTest is Test {
    UniswapV1Factory factory;

    ERC20Mock tokenA;
    ERC20Mock tokenB;

    UniswapV1Exchange exchangeA;
    UniswapV1Exchange exchangeB;

    address USER = makeAddr("USER");
    address USER2 = makeAddr("USER2");

    function setUp() public {
        factory = new UniswapV1Factory();

        tokenA = new ERC20Mock();
        tokenB = new ERC20Mock();

        address exchangeAAddress = factory.createExchange(address(tokenA), "Uniswap V1 Token A", "UNI-A");
        address exchangeBAddress = factory.createExchange(address(tokenB), "Uniswap V1 Token B", "UNI-B");

        exchangeA = UniswapV1Exchange(payable(exchangeAAddress));
        exchangeB = UniswapV1Exchange(payable(exchangeBAddress));
    }

    modifier withTokenToTokenLiquidity() {
        deal(address(exchangeA), 10 ether);
        deal(address(exchangeB), 10 ether);

        tokenA.mint(address(exchangeA), 1_000 ether);
        tokenB.mint(address(exchangeB), 1_000 ether);
        _;
    }

    // tokenToTokenSwapInput

    function test_TokenToTokenSwapInput() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensBought = exchangeA.tokenToTokenSwapInput(tokensSold, 1, 1, block.timestamp, address(tokenB));
        vm.stopPrank();

        assertEq(actualTokensBought, tokensBought);
        assertEq(tokenA.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER), tokensBought);

        assertEq(tokenA.balanceOf(address(exchangeA)), 1_000 ether + tokensSold);
        assertEq(address(exchangeA).balance, 10 ether - ethBought);

        assertEq(address(exchangeB).balance, 10 ether + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), 1_000 ether - tokensBought);
    }

    function test_TokenToTokenSwapInputEmitsEvent() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectEmit(true, false, false, true, address(exchangeA));
        emit UniswapV1Exchange.EthPurchase(USER, tokensSold, ethBought);

        exchangeA.tokenToTokenSwapInput(tokensSold, 1, 1, block.timestamp, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenSwapInputRevertsWhenTokensSoldIsZero() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);
        exchangeA.tokenToTokenSwapInput(0, 1, 1, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenSwapInputRevertsWhenMinTokensBoughtIsZero() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensBoughtIsZero.selector);
        exchangeA.tokenToTokenSwapInput(100 ether, 0, 1, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenSwapInputRevertsWhenMinEthBoughtIsZero() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthBoughtIsZero.selector);
        exchangeA.tokenToTokenSwapInput(100 ether, 1, 0, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenSwapInputRevertsWhenDeadlinePassed() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchangeA.tokenToTokenSwapInput(tokensSold, 1, 1, block.timestamp - 1, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenSwapInputRevertsWhenMinEthBoughtTooHigh() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthBought.selector);
        exchangeA.tokenToTokenSwapInput(tokensSold, 1, ethBought + 1, block.timestamp, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenSwapInputRevertsWhenMinTokensBoughtTooHigh() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensBought.selector);
        exchangeA.tokenToTokenSwapInput(tokensSold, tokensBought + 1, 1, block.timestamp, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenSwapInputRevertsWhenOutputTokenHasNoExchange() public withTokenToTokenLiquidity {
        ERC20Mock tokenC = new ERC20Mock();
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenSwapInput(100 ether, 1, 1, block.timestamp, address(tokenC));
    }

    function test_TokenToTokenSwapInputRevertsWhenOutputTokenIsSameToken() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenSwapInput(100 ether, 1, 1, block.timestamp, address(tokenA));
    }

    function test_TokenToTokenSwapInputRevertsWhenTokenTransferFails() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.mockCall(
            address(tokenA),
            abi.encodeWithSelector(tokenA.transferFrom.selector, USER, address(exchangeA), tokensSold),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector, USER, address(exchangeA), tokensSold
            )
        );
        exchangeA.tokenToTokenSwapInput(tokensSold, 1, 1, block.timestamp, address(tokenB));
        vm.stopPrank();
    }

    // tokenToTokenTransferInput

    function test_TokenToTokenTransferInput() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensBought =
            exchangeA.tokenToTokenTransferInput(tokensSold, 1, 1, block.timestamp, USER2, address(tokenB));
        vm.stopPrank();

        assertEq(actualTokensBought, tokensBought);
        assertEq(tokenA.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER2), tokensBought);

        assertEq(tokenA.balanceOf(address(exchangeA)), 1_000 ether + tokensSold);
        assertEq(address(exchangeA).balance, 10 ether - ethBought);

        assertEq(address(exchangeB).balance, 10 ether + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), 1_000 ether - tokensBought);
    }

    function test_TokenToTokenTransferInputEmitsEvent() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectEmit(true, false, false, true, address(exchangeA));
        emit UniswapV1Exchange.EthPurchase(USER, tokensSold, ethBought);

        exchangeA.tokenToTokenTransferInput(tokensSold, 1, 1, block.timestamp, USER2, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenTransferInputRevertsWhenTokensSoldIsZero() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldIsZero.selector);
        exchangeA.tokenToTokenTransferInput(0, 1, 1, block.timestamp, USER2, address(tokenB));
    }

    function test_TokenToTokenTransferInputRevertsWhenMinTokensBoughtIsZero() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinTokensBoughtIsZero.selector);
        exchangeA.tokenToTokenTransferInput(100 ether, 0, 1, block.timestamp, USER2, address(tokenB));
    }

    function test_TokenToTokenTransferInputRevertsWhenMinEthBoughtIsZero() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MinEthBoughtIsZero.selector);
        exchangeA.tokenToTokenTransferInput(100 ether, 1, 0, block.timestamp, USER2, address(tokenB));
    }

    function test_TokenToTokenTransferInputRevertsWhenDeadlinePassed() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchangeA.tokenToTokenTransferInput(tokensSold, 1, 1, block.timestamp - 1, USER2, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenTransferInputRevertsWhenMinEthBoughtTooHigh() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientEthBought.selector);
        exchangeA.tokenToTokenTransferInput(tokensSold, 1, ethBought + 1, block.timestamp, USER2, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenTransferInputRevertsWhenMinTokensBoughtTooHigh() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InsufficientTokensBought.selector);
        exchangeA.tokenToTokenTransferInput(tokensSold, tokensBought + 1, 1, block.timestamp, USER2, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenTransferInputRevertsWhenOutputTokenHasNoExchange() public withTokenToTokenLiquidity {
        ERC20Mock tokenC = new ERC20Mock();
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenTransferInput(100 ether, 1, 1, block.timestamp, USER2, address(tokenC));
    }

    function test_TokenToTokenTransferInputRevertsWhenOutputTokenIsSameToken() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenTransferInput(100 ether, 1, 1, block.timestamp, USER2, address(tokenA));
    }

    function test_TokenToTokenTransferInputRevertsWhenRecipientIsZeroAddress() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToTokenTransferInput(100 ether, 1, 1, block.timestamp, address(0), address(tokenB));
    }

    function test_TokenToTokenTransferInputRevertsWhenRecipientIsExchange() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToTokenTransferInput(100 ether, 1, 1, block.timestamp, address(exchangeA), address(tokenB));
    }

    function test_TokenToTokenTransferInputRevertsWhenTokenTransferFails() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.mockCall(
            address(tokenA),
            abi.encodeWithSelector(tokenA.transferFrom.selector, USER, address(exchangeA), tokensSold),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector, USER, address(exchangeA), tokensSold
            )
        );
        exchangeA.tokenToTokenTransferInput(tokensSold, 1, 1, block.timestamp, USER2, address(tokenB));
        vm.stopPrank();
    }

    // tokenToTokenSwapOutput

    function test_TokenToTokenSwapOutput() public withTokenToTokenLiquidity {
        uint256 tokenAReserve = 1_000 ether;
        uint256 tokenBReserve = 1_000 ether;
        uint256 ethReserveA = 10 ether;
        uint256 ethReserveB = 10 ether;

        uint256 tokensBought = 100 ether;

        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensSold =
            exchangeA.tokenToTokenSwapOutput(tokensBought, tokensSold, ethBought, block.timestamp, address(tokenB));
        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);
        assertEq(tokenA.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER), tokensBought);

        assertEq(tokenA.balanceOf(address(exchangeA)), tokenAReserve + tokensSold);
        assertEq(address(exchangeA).balance, ethReserveA - ethBought);

        assertEq(address(exchangeB).balance, ethReserveB + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), tokenBReserve - tokensBought);
    }

    function test_TokenToTokenSwapOutputEmitsEvent() public withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;
        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectEmit(true, false, false, true, address(exchangeA));
        emit UniswapV1Exchange.EthPurchase(USER, tokensSold, ethBought);

        exchangeA.tokenToTokenSwapOutput(tokensBought, tokensSold, ethBought, block.timestamp, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenSwapOutputRevertsWhenTokensBoughtIsZero() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensBoughtIsZero.selector);
        exchangeA.tokenToTokenSwapOutput(0, 1, 1, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenSwapOutputRevertsWhenMaxEthSoldIsZero() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__MaxEthIsZero.selector);
        exchangeA.tokenToTokenSwapOutput(100 ether, 1_000 ether, 0, block.timestamp, address(tokenB));
    }

    function test_TokenToTokenSwapOutputRevertsWhenDeadlinePassed() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__DeadlineExpired.selector);
        exchangeA.tokenToTokenSwapOutput(100 ether, 1_000 ether, 1 ether, block.timestamp - 1, address(tokenB));
    }

    function test_TokenToTokenSwapOutputRevertsWhenEthBoughtExceedsMaxEthSold() public withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;
        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EthBoughtExceedsMaxEthSold.selector);
        exchangeA.tokenToTokenSwapOutput(
            tokensBought, type(uint256).max, ethBought - 1, block.timestamp, address(tokenB)
        );
    }

    function test_TokenToTokenSwapOutputRevertsWhenTokensSoldExceedsMaxTokensSold() public withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;
        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__TokensSoldExceedsMaxTokensSold.selector);
        exchangeA.tokenToTokenSwapOutput(tokensBought, tokensSold - 1, ethBought, block.timestamp, address(tokenB));
        vm.stopPrank();
    }

    function test_TokenToTokenSwapOutputRevertsWhenOutputTokenHasNoExchange() public withTokenToTokenLiquidity {
        ERC20Mock tokenC = new ERC20Mock();
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenSwapOutput(100 ether, 1_000 ether, 1 ether, block.timestamp, address(tokenC));
    }

    function test_TokenToTokenSwapOutputRevertsWhenOutputTokenIsSameToken() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToTokenSwapOutput(100 ether, 1_000 ether, 1 ether, block.timestamp, address(tokenA));
    }

    function test_TokenToTokenSwapOutputRevertsWhenTokenTransferFails() public withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;
        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.mockCall(
            address(tokenA),
            abi.encodeWithSelector(tokenA.transferFrom.selector, USER, address(exchangeA), tokensSold),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                UniswapV1Exchange.UniswapV1Exchange__TokensTransferFailed.selector, USER, address(exchangeA), tokensSold
            )
        );
        exchangeA.tokenToTokenSwapOutput(tokensBought, tokensSold, ethBought, block.timestamp, address(tokenB));
        vm.stopPrank();
    }

    // tokenToTokenTransferOutput

    function test_TokenToTokenTransferOutput() public withTokenToTokenLiquidity {
        uint256 tokenAReserve = 1_000 ether;
        uint256 tokenBReserve = 1_000 ether;
        uint256 ethReserveA = 10 ether;
        uint256 ethReserveB = 10 ether;

        uint256 tokensBought = 100 ether;

        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensSold = exchangeA.tokenToTokenTransferOutput(
            tokensBought, tokensSold, ethBought, block.timestamp, USER2, address(tokenB)
        );
        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);
        assertEq(tokenA.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER2), tokensBought);

        assertEq(tokenA.balanceOf(address(exchangeA)), tokenAReserve + tokensSold);
        assertEq(address(exchangeA).balance, ethReserveA - ethBought);

        assertEq(address(exchangeB).balance, ethReserveB + ethBought);
        assertEq(tokenB.balanceOf(address(exchangeB)), tokenBReserve - tokensBought);
    }

    function test_TokenToTokenTransferOutputEmitsEvent() public withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;
        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        vm.expectEmit(true, false, false, true, address(exchangeA));
        emit UniswapV1Exchange.EthPurchase(USER, tokensSold, ethBought);

        exchangeA.tokenToTokenTransferOutput(
            tokensBought, tokensSold, ethBought, block.timestamp, USER2, address(tokenB)
        );
        vm.stopPrank();
    }

    function test_TokenToTokenTransferOutputRevertsWhenRecipientIsZeroAddress() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToTokenTransferOutput(
            100 ether, 1_000 ether, 1 ether, block.timestamp, address(0), address(tokenB)
        );
    }

    function test_TokenToTokenTransferOutputRevertsWhenRecipientIsExchange() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToTokenTransferOutput(
            100 ether, 1_000 ether, 1 ether, block.timestamp, address(exchangeA), address(tokenB)
        );
    }

    // tokenToExchangeSwapInput

    function test_TokenToExchangeSwapInput() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensBought =
            exchangeA.tokenToExchangeSwapInput(tokensSold, 1, 1, block.timestamp, payable(address(exchangeB)));
        vm.stopPrank();

        assertEq(actualTokensBought, tokensBought);
        assertEq(tokenA.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER), tokensBought);
    }

    function test_TokenToExchangeSwapInputRevertsWhenExchangeIsZeroAddress() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToExchangeSwapInput(100 ether, 1, 1, block.timestamp, payable(address(0)));
    }

    function test_TokenToExchangeSwapInputRevertsWhenExchangeIsThisAddress() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToExchangeSwapInput(100 ether, 1, 1, block.timestamp, payable(address(exchangeA)));
    }

    // tokenToExchangeTransferInput

    function test_TokenToExchangeTransferInput() public withTokenToTokenLiquidity {
        uint256 tokensSold = 100 ether;
        deal(address(tokenA), USER, tokensSold);

        uint256 ethBought = exchangeA.getTokenToEthInputPrice(tokensSold);
        uint256 tokensBought = exchangeB.getEthToTokenInputPrice(ethBought);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensBought = exchangeA.tokenToExchangeTransferInput(
            tokensSold, 1, 1, block.timestamp, USER2, payable(address(exchangeB))
        );
        vm.stopPrank();

        assertEq(actualTokensBought, tokensBought);
        assertEq(tokenA.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER2), tokensBought);
    }

    function test_TokenToExchangeTransferInputRevertsWhenRecipientIsZeroAddress() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToExchangeTransferInput(
            100 ether, 1, 1, block.timestamp, address(0), payable(address(exchangeB))
        );
    }

    function test_TokenToExchangeTransferInputRevertsWhenRecipientIsExchange() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToExchangeTransferInput(
            100 ether, 1, 1, block.timestamp, address(exchangeA), payable(address(exchangeB))
        );
    }

    // tokenToExchangeSwapOutput

    function test_TokenToExchangeSwapOutput() public withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;
        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensSold = exchangeA.tokenToExchangeSwapOutput(
            tokensBought, tokensSold, ethBought, block.timestamp, payable(address(exchangeB))
        );
        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);
        assertEq(tokenA.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER), tokensBought);
    }

    function test_TokenToExchangeSwapOutputRevertsWhenExchangeIsZeroAddress() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToExchangeSwapOutput(100 ether, 1_000 ether, 1 ether, block.timestamp, payable(address(0)));
    }

    function test_TokenToExchangeSwapOutputRevertsWhenExchangeIsThisAddress() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidExchangeAddress.selector);
        exchangeA.tokenToExchangeSwapOutput(
            100 ether, 1_000 ether, 1 ether, block.timestamp, payable(address(exchangeA))
        );
    }

    // tokenToExchangeTransferOutput

    function test_TokenToExchangeTransferOutput() public withTokenToTokenLiquidity {
        uint256 tokensBought = 100 ether;
        uint256 ethBought = exchangeB.getEthToTokenOutputPrice(tokensBought);
        uint256 tokensSold = exchangeA.getTokenToEthOutputPrice(ethBought);

        deal(address(tokenA), USER, tokensSold);

        vm.startPrank(USER);
        tokenA.approve(address(exchangeA), tokensSold);

        uint256 actualTokensSold = exchangeA.tokenToExchangeTransferOutput(
            tokensBought, tokensSold, ethBought, block.timestamp, USER2, payable(address(exchangeB))
        );
        vm.stopPrank();

        assertEq(actualTokensSold, tokensSold);
        assertEq(tokenA.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER), 0);
        assertEq(tokenB.balanceOf(USER2), tokensBought);
    }

    function test_TokenToExchangeTransferOutputRevertsWhenRecipientIsZeroAddress() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToExchangeTransferOutput(
            100 ether, 1_000 ether, 1 ether, block.timestamp, address(0), payable(address(exchangeB))
        );
    }

    function test_TokenToExchangeTransferOutputRevertsWhenRecipientIsExchange() public withTokenToTokenLiquidity {
        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__InvalidRecipient.selector);
        exchangeA.tokenToExchangeTransferOutput(
            100 ether, 1_000 ether, 1 ether, block.timestamp, address(exchangeA), payable(address(exchangeB))
        );
    }
}
