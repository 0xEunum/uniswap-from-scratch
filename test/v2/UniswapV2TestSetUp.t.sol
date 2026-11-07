// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {UniswapV2Router} from "src/v2/UniswapV2Router.sol";
import {UniswapV2Factory} from "src/v2/UniswapV2Factory.sol";
import {UniswapV2Pair} from "src/v2/UniswapV2Pair.sol";

import {UniswapV2HelperConfig} from "script/v2/UniswapV2HelperConfig.s.sol";

import {IUniswapV2Pair} from "src/v2/interfaces/IUniswapV2Pair.sol";
import {IWETH} from "src/v2/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV2TestSetUp is Test {
    address OWNER = makeAddr("OWNER");
    address USER = makeAddr("USER");
    address USER2 = makeAddr("USER2");

    UniswapV2Router router;
    UniswapV2Factory factory;
    UniswapV2Pair pair;

    IWETH WETH;
    IERC20 DAI;
    IERC20 MKR;

    UniswapV2HelperConfig helperConfig;

    uint256 public constant FEE_MULTIPLIER = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    function setUp() public virtual {
        helperConfig = new UniswapV2HelperConfig();
        (address weth, address dai, address mkr, address _factory, address _router) = helperConfig.addressesConfig();
        WETH = IWETH(weth);
        DAI = IERC20(dai);
        MKR = IERC20(mkr);
        factory = UniswapV2Factory(_factory);
        router = UniswapV2Router(_router);
    }
}
