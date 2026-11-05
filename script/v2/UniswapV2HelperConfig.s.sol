// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import {UniswapV2Factory} from "src/v2/UniswapV2Factory.sol";
import {UniswapV2Router} from "src/v2/UniswapV2Router.sol";

contract UniswapV2HelperConfig is Script {
    error UniswapV2HelperConfig__InvalidChain();

    uint256 constant MAINNET_CHAIN_ID = 1;
    uint256 constant ANVIL_CHAIN_ID = 31337;

    struct AddressesConfig {
        address weth;
        address dai;
        address mkr;
        address factory;
        address router;
    }

    AddressesConfig public addressesConfig;

    constructor() {
        if (block.chainid == MAINNET_CHAIN_ID) {
            addressesConfig = _getMainnetAddresses();
        } else if (block.chainid == ANVIL_CHAIN_ID) {
            addressesConfig = _getAnvilAddresses();
        } else {
            revert UniswapV2HelperConfig__InvalidChain();
        }
    }

    function _getMainnetAddresses() private pure returns (AddressesConfig memory) {
        AddressesConfig memory mainnetConfig = AddressesConfig({
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            dai: 0x6B175474E89094C44Da98b954EedeAC495271d0F,
            mkr: 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2,
            factory: 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
            router: 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        });

        return mainnetConfig;
    }

    function _getAnvilAddresses() private returns (AddressesConfig memory) {
        ERC20Mock weth = new ERC20Mock();
        ERC20Mock dai = new ERC20Mock();
        ERC20Mock mkr = new ERC20Mock();

        UniswapV2Factory factory = new UniswapV2Factory();
        UniswapV2Router router = new UniswapV2Router();

        AddressesConfig memory anvilConfig = AddressesConfig({
            weth: address(weth),
            dai: address(dai),
            mkr: address(mkr),
            factory: address(factory),
            router: address(router)
        });

        return anvilConfig;
    }
}
