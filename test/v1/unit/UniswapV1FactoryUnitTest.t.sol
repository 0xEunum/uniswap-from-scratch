// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/v1/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/v1/UniswapV1Factory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1FactoryUnitTest is Test {
    UniswapV1Factory factory;
    ERC20Mock token;

    address OWNER = makeAddr("OWNER");
    address USER = makeAddr("USER");

    function setUp() public {
        vm.startPrank(OWNER);
        factory = new UniswapV1Factory();
        token = new ERC20Mock();
        vm.stopPrank();
    }

    function test_FactoryInitialState() public view {
        assertEq(factory.tokenCounter(), 0);
        assertEq(factory.getTokenAddrWithId(1), address(0));
        assertEq(factory.getExchangeAddr(address(token)), address(0));
    }

    function test_CreateExchange() public {
        string memory tokenName = token.name();
        string memory tokenSymbol = token.symbol();

        address exchangeAddr = factory.createExchange(address(token), tokenName, tokenSymbol);
        UniswapV1Exchange exchange = UniswapV1Exchange(exchangeAddr);

        string memory expectedTokenName = exchange.name();
        string memory expectedTokenSymbol = exchange.symbol();

        assertEq(expectedTokenName, tokenName);
        assertEq(expectedTokenSymbol, tokenSymbol);

        assertEq(factory.getExchangeAddr(address(token)), address(exchange));
        assertEq(factory.getTokenAddr(address(exchange)), address(token));
        assertEq(factory.tokenCounter(), 1);
        assertEq(factory.getTokenAddrWithId(1), address(token));

        assertEq(exchange.decimals(), token.decimals());
        assertEq(exchange.totalSupply(), 0);
        assertEq(exchange.I_FACTORY(), address(factory));
        assertEq(address(exchange).balance, 0);
        assertEq(token.balanceOf(address(exchange)), 0);
    }

    function test_CreateExchangeReverts() public {
        string memory tokenName = token.name();
        string memory tokenSymbol = token.symbol();

        vm.expectRevert(UniswapV1Factory.UniswapV1Factory__ZeroAddress.selector);
        factory.createExchange(address(0), tokenName, tokenSymbol);

        factory.createExchange(address(token), tokenName, tokenSymbol);

        vm.expectRevert(UniswapV1Factory.UniswapV1Factory__ExchangeAlreadyExists.selector);
        factory.createExchange(address(token), tokenName, tokenSymbol);
    }
}
