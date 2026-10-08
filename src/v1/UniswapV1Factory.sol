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

import {UniswapV1Exchange} from "src/v1/UniswapV1Exchange.sol";

/**
 * @title UniswapV1Factory
 * @notice Factory and registry contract to deploy and track Uniswap V1 exchange pairs.
 * @dev Manages a 1:1 mapping between ERC20 token addresses and their dedicated UniswapV1Exchange contracts.
 */
contract UniswapV1Factory {
    /*//////////////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////////////*/
    error UniswapV1Factory__ZeroAddress();
    error UniswapV1Factory__ExchangeAlreadyExists();

    /*//////////////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////////////*/
    mapping(address token => address exchange) private s_tokenToExchange;
    mapping(address exchange => address token) private s_exchangeToToken;
    mapping(uint256 id => address token) private s_idToToken;

    /// @notice Total number of exchanges deployed by this factory (1-based indexing).
    uint256 public tokenCounter;

    /*//////////////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////////////*/
    event NewExchange(address indexed token, address indexed exchange);

    /*//////////////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/
    /*//////////////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys a new UniswapV1Exchange for the given ERC20 token.
     * @param _token The address of the ERC20 token to create an exchange for.
     * @param _lpTokenName The name of the LP token issued by the exchange.
     * @param _lpTokenSymbol The symbol of the LP token issued by the exchange.
     * @return exchange The address of the newly deployed exchange contract.
     */
    function createExchange(address _token, string memory _lpTokenName, string memory _lpTokenSymbol)
        external
        returns (address exchange)
    {
        if (_token == address(0)) {
            revert UniswapV1Factory__ZeroAddress();
        }

        if (s_tokenToExchange[_token] != address(0)) {
            revert UniswapV1Factory__ExchangeAlreadyExists();
        }

        UniswapV1Exchange newExchange = new UniswapV1Exchange(_token, address(this), _lpTokenName, _lpTokenSymbol);

        s_tokenToExchange[_token] = address(newExchange);
        s_exchangeToToken[address(newExchange)] = _token;

        tokenCounter++;
        s_idToToken[tokenCounter] = _token;

        emit NewExchange(_token, address(newExchange));

        return address(newExchange);
    }

    /*//////////////////////////////////////////////////////////////////////
                      EXTERNAL & PUBLIC VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the exchange address registered for a given token.
     * @param _token The ERC20 token address.
     * @return exchange The corresponding exchange address.
     */
    function getExchangeAddr(address _token) external view returns (address exchange) {
        return s_tokenToExchange[_token];
    }

    /**
     * @notice Gets the token address registered for a given exchange.
     * @param _exchange The exchange address.
     * @return token The corresponding ERC20 token address.
     */
    function getTokenAddr(address _exchange) external view returns (address token) {
        return s_exchangeToToken[_exchange];
    }

    /**
     * @notice Gets the token address associated with an exchange launch sequence ID.
     * @param _id Unique ID index (1-based).
     * @return token The ERC20 token address registered at that ID.
     */
    function getTokenAddrWithId(uint256 _id) external view returns (address token) {
        return s_idToToken[_id];
    }
}
