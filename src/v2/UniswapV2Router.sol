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

import {UniswapV2Pair} from "./UniswapV2Pair.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";

/**
 * @title UniswapV2Router
 * @notice Periphery contract for Uniswap V2 that handles multi-hop swaps, liquidity provision, and price calculations.
 */
contract UniswapV2Router {
    /*//////////////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////////////*/
    error UniswapV2Router__ZeroAmount();
    error UniswapV2Router__ZeroAmountIn();
    error UniswapV2Router__ZeroAmountOut();
    error UniswapV2Router__ZeroReserves();
    error UniswapV2Router__InsufficientOutputReserve();
    error UniswapV2Router__IdenticalAddresses();
    error UniswapV2Router__ZeroAddress();
    error UniswapV2Router__InvalidPath();

    /*//////////////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////////////*/
    /// @notice The multiplier representing (1000 - 3) = 997, accounting for the 0.3% trading fee.
    uint256 private constant FEE_MULTIPLIER = 997;

    /// @notice The fee denominator representing 1000 (100%).
    uint256 private constant FEE_DENOMINATOR = 1000;

    /*//////////////////////////////////////////////////////////////////////
                    INTERNAL & PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Sorts two token addresses into canonical order (token0 < token1).
     * @dev Reverts if addresses are identical or if the first token is address(0).
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @return token0 The smaller token address.
     * @return token1 The larger token address.
     */
    function _sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        if (_tokenA == _tokenB) {
            revert UniswapV2Router__IdenticalAddresses();
        }

        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);

        if (token0 == address(0)) {
            revert UniswapV2Router__ZeroAddress();
        }
    }

    /**
     * @notice Calculates the deterministic CREATE2 address for a pair without making an external call.
     * @param _factory Address of the Uniswap V2 Factory.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @return pair Address of the corresponding UniswapV2Pair contract.
     */
    function _pairFor(address _factory, address _tokenA, address _tokenB) internal pure returns (address pair) {
        (address token0, address token1) = _sortTokens(_tokenA, _tokenB);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            _factory,
                            keccak256(abi.encodePacked(token0, token1)),
                            keccak256(type(UniswapV2Pair).creationCode)
                        )
                    )
                )
            )
        );
    }

    /**
     * @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset.
     * @dev Used for calculating optimal liquidity deposits: amountB = (amountA * reserveB) / reserveA.
     * @param _amountA Amount of asset A.
     * @param _reserveA Reserve of asset A in the pool.
     * @param _reserveB Reserve of asset B in the pool.
     * @return amountB Equivalent amount of asset B.
     */
    function _quote(uint256 _amountA, uint256 _reserveA, uint256 _reserveB) internal pure returns (uint256 amountB) {
        if (_amountA == 0) {
            revert UniswapV2Router__ZeroAmount();
        }

        if (_reserveA == 0 || _reserveB == 0) {
            revert UniswapV2Router__ZeroReserves();
        }

        return (_amountA * _reserveB) / _reserveA;
    }

    /**
     * @notice Calculates the output asset amount received given an input asset amount and pair reserves.
     * @dev Follows constant product formula (x + Δx * 0.997)(y - Δy) = xy.
     *      Solving for Δy gives Δy = (Δx * 997 * y) / (x * 1000 + Δx * 997).
     * @param _amountIn Amount of input asset being sold.
     * @param _reserveIn Current reserve of input asset in the pool.
     * @param _reserveOut Current reserve of output asset in the pool.
     * @return amountOut Amount of output asset received.
     */
    function _getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut)
        internal
        pure
        returns (uint256 amountOut)
    {
        if (_amountIn == 0) {
            revert UniswapV2Router__ZeroAmountIn();
        }

        if (_reserveIn == 0 || _reserveOut == 0) {
            revert UniswapV2Router__ZeroReserves();
        }

        uint256 amountInWithFee = _amountIn * FEE_MULTIPLIER;
        uint256 numerator = amountInWithFee * _reserveOut;
        uint256 denominator = (_reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        return numerator / denominator;
    }

    /**
     * @notice Calculates the required input asset amount given a desired output asset amount and pair reserves.
     * @dev Follows constant product formula (x + Δx * 0.997)(y - Δy) = xy.
     *      Solving for Δx gives Δx = (x * Δy * 1000) / ((y - Δy) * 997).
     *      Adds 1 to round up in favor of the pool, preventing integer truncation loss.
     * @param _amountOut Desired amount of output asset.
     * @param _reserveIn Current reserve of input asset in the pool.
     * @param _reserveOut Current reserve of output asset in the pool.
     * @return amountIn Required amount of input asset to sell.
     */
    function _getAmountIn(uint256 _amountOut, uint256 _reserveIn, uint256 _reserveOut)
        internal
        pure
        returns (uint256 amountIn)
    {
        if (_amountOut == 0) {
            revert UniswapV2Router__ZeroAmountOut();
        }

        if (_reserveIn == 0 || _reserveOut == 0) {
            revert UniswapV2Router__ZeroReserves();
        }

        if (_amountOut >= _reserveOut) {
            revert UniswapV2Router__InsufficientOutputReserve();
        }

        uint256 numerator = _reserveIn * _amountOut * FEE_DENOMINATOR;
        uint256 denominator = (_reserveOut - _amountOut) * FEE_MULTIPLIER;
        return (numerator / denominator) + 1;
    }

    /**
     * @notice Fetches and sorts the reserves for a given pair.
     * @param _factory Address of the Uniswap V2 Factory.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @return reserveA Current reserve of tokenA in the pool.
     * @return reserveB Current reserve of tokenB in the pool.
     */
    function _getReserves(address _factory, address _tokenA, address _tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0,) = _sortTokens(_tokenA, _tokenB);
        address pair = _pairFor(_factory, _tokenA, _tokenB);
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(pair).getReserves();
        (reserveA, reserveB) = _tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @notice Performs chained getAmountOut calculations along an arbitrary token swap path.
     * @param _factory Address of the Uniswap V2 Factory.
     * @param _amountIn Initial amount of the first token to sell.
     * @param _path Array of token addresses representing the multi-hop swap route.
     * @return amounts Array of token amounts received at each step of the path.
     */
    function _getAmountsOut(address _factory, uint256 _amountIn, address[] memory _path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (_path.length < 2) {
            revert UniswapV2Router__InvalidPath();
        }

        amounts = new uint256[](_path.length);
        amounts[0] = _amountIn;

        for (uint256 i = 0; i < _path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(_factory, _path[i], _path[i + 1]);
            amounts[i + 1] = _getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @notice Performs chained getAmountIn calculations along an arbitrary token swap path in reverse.
     * @param _factory Address of the Uniswap V2 Factory.
     * @param _amountOut Final amount of the last token to buy.
     * @param _path Array of token addresses representing the multi-hop swap route.
     * @return amounts Array of token amounts required at each step of the path.
     */
    function _getAmountsIn(address _factory, uint256 _amountOut, address[] memory _path)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (_path.length < 2) {
            revert UniswapV2Router__InvalidPath();
        }

        amounts = new uint256[](_path.length);
        amounts[_path.length - 1] = _amountOut;

        for (uint256 i = _path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = _getReserves(_factory, _path[i - 1], _path[i]);
            amounts[i - 1] = _getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    /*//////////////////////////////////////////////////////////////////////
                    EXTERNAL & PUBLIC VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Sorts two token addresses into canonical order (token0 < token1).
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @return token0 The smaller token address.
     * @return token1 The larger token address.
     */
    function sortTokens(address _tokenA, address _tokenB) external pure returns (address token0, address token1) {
        return _sortTokens(_tokenA, _tokenB);
    }

    /**
     * @notice Calculates the deterministic CREATE2 address for a pair without making an external call.
     * @param _factory Address of the Uniswap V2 Factory.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @return pair Address of the corresponding UniswapV2Pair contract.
     */
    function pairFor(address _factory, address _tokenA, address _tokenB) external pure returns (address pair) {
        return _pairFor(_factory, _tokenA, _tokenB);
    }

    /**
     * @notice Given some amount of an asset and pair reserves, returns an equivalent amount of the other asset.
     * @param _amountA Amount of asset A.
     * @param _reserveA Reserve of asset A in the pool.
     * @param _reserveB Reserve of asset B in the pool.
     * @return amountB Equivalent amount of asset B.
     */
    function quote(uint256 _amountA, uint256 _reserveA, uint256 _reserveB) external pure returns (uint256 amountB) {
        return _quote(_amountA, _reserveA, _reserveB);
    }

    /**
     * @notice Returns the output asset amount received given an input asset amount and pair reserves.
     * @param _amountIn Amount of input asset being sold.
     * @param _reserveIn Current reserve of input asset in the pool.
     * @param _reserveOut Current reserve of output asset in the pool.
     * @return amountOut Amount of output asset received.
     */
    function getAmountOut(uint256 _amountIn, uint256 _reserveIn, uint256 _reserveOut)
        external
        pure
        returns (uint256 amountOut)
    {
        return _getAmountOut(_amountIn, _reserveIn, _reserveOut);
    }

    /**
     * @notice Returns the required input asset amount given a desired output asset amount and pair reserves.
     * @param _amountOut Desired amount of output asset.
     * @param _reserveIn Current reserve of input asset in the pool.
     * @param _reserveOut Current reserve of output asset in the pool.
     * @return amountIn Required amount of input asset to sell.
     */
    function getAmountIn(uint256 _amountOut, uint256 _reserveIn, uint256 _reserveOut)
        external
        pure
        returns (uint256 amountIn)
    {
        return _getAmountIn(_amountOut, _reserveIn, _reserveOut);
    }

    /**
     * @notice Fetches and sorts the reserves for a given pair.
     * @param _factory Address of the Uniswap V2 Factory.
     * @param _tokenA Address of the first token.
     * @param _tokenB Address of the second token.
     * @return reserveA Current reserve of tokenA in the pool.
     * @return reserveB Current reserve of tokenB in the pool.
     */
    function getReserves(address _factory, address _tokenA, address _tokenB)
        external
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        return _getReserves(_factory, _tokenA, _tokenB);
    }

    /**
     * @notice Performs chained getAmountOut calculations along an arbitrary token swap path.
     * @param _factory Address of the Uniswap V2 Factory.
     * @param _amountIn Initial amount of the first token to sell.
     * @param _path Array of token addresses representing the multi-hop swap route.
     * @return amounts Array of token amounts received at each step of the path.
     */
    function getAmountsOut(address _factory, uint256 _amountIn, address[] memory _path)
        external
        view
        returns (uint256[] memory amounts)
    {
        return _getAmountsOut(_factory, _amountIn, _path);
    }

    /**
     * @notice Performs chained getAmountIn calculations along an arbitrary token swap path in reverse.
     * @param _factory Address of the Uniswap V2 Factory.
     * @param _amountOut Final amount of the last token to buy.
     * @param _path Array of token addresses representing the multi-hop swap route.
     * @return amounts Array of token amounts required at each step of the path.
     */
    function getAmountsIn(address _factory, uint256 _amountOut, address[] memory _path)
        external
        view
        returns (uint256[] memory amounts)
    {
        return _getAmountsIn(_factory, _amountOut, _path);
    }
}
