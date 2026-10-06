// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title UniswapV1Exchange
 * @notice An automated market maker (AMM) exchange contract for a single ERC20 token paired with ETH.
 * @dev Inherits Openzeppelin ERC20 to issue LP (Liquidity Provider) tokens representing pooled shares.
 */
contract UniswapV1Exchange is ERC20 {
    /*//////////////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////////////*/
    error UniswapV1Exchange__ZeroAddress();
    error UniswapV1Exchange__EmptyTokenNameOrSymbol();

    /*//////////////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////////////*/
    IERC20 public immutable I_TOKEN;
    address public immutable I_FACTORY;

    /*//////////////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/
    constructor(address _token, address _factory, string memory _lpTokenName, string memory _lpTokenSymbol)
        ERC20(_lpTokenName, _lpTokenSymbol)
    {
        if (_token == address(0) || _factory == address(0)) {
            revert UniswapV1Exchange__ZeroAddress();
        }

        if (bytes(_lpTokenName).length == 0 || bytes(_lpTokenSymbol).length == 0) {
            revert UniswapV1Exchange__EmptyTokenNameOrSymbol();
        }

        I_TOKEN = IERC20(_token);
        I_FACTORY = _factory;
    }
}
