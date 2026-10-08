// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV1Exchange} from "src/v1/UniswapV1Exchange.sol";
import {UniswapV1Factory} from "src/v1/UniswapV1Factory.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UniswapV1ExchangeUnitTest is Test {
    UniswapV1Exchange exchange;
    UniswapV1Factory factory;
    ERC20Mock token;

    address OWNER = makeAddr("OWNER");
    address USER = makeAddr("USER");
    address USER2 = makeAddr("USER2");

    function setUp() external {
        vm.startPrank(OWNER);
        factory = new UniswapV1Factory();
        token = new ERC20Mock();
        exchange = new UniswapV1Exchange(address(token), address(factory), token.name(), token.symbol());
        vm.stopPrank();
    }

    modifier addFakeLiquidity(uint256 ethReserve, uint256 tokenReserve) {
        deal(address(exchange), ethReserve);
        token.mint(address(exchange), tokenReserve);
        _;
    }

    //constructor
    function test_constructorArgumentsAreSetCorrectly() external view {
        address expectedTokenAddress = address(exchange.I_TOKEN());
        address expectedFactoryAddress = exchange.I_FACTORY();

        assertEq(expectedTokenAddress, address(token));
        assertEq(expectedFactoryAddress, address(factory));

        string memory expectedTokenName = token.name();
        string memory expectedTokenSymbol = token.symbol();

        assertEq(exchange.name(), expectedTokenName);
        assertEq(exchange.symbol(), expectedTokenSymbol);
    }

    function test_constructorArgumentsErrorsReverts() external {
        string memory tokenName = token.name();
        string memory tokenSymbol = token.symbol();

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroAddress.selector);
        new UniswapV1Exchange(address(0), address(factory), tokenName, tokenSymbol);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__ZeroAddress.selector);
        new UniswapV1Exchange(address(token), address(0), tokenName, tokenSymbol);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EmptyTokenNameOrSymbol.selector);
        new UniswapV1Exchange(address(token), address(factory), "", tokenSymbol);

        vm.expectRevert(UniswapV1Exchange.UniswapV1Exchange__EmptyTokenNameOrSymbol.selector);
        new UniswapV1Exchange(address(token), address(factory), tokenName, "");
    }
}
