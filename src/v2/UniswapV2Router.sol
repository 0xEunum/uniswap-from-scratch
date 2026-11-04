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

/**
 * @title UniswapV2Router
 * @notice Periphery contract for Uniswap V2 that handles multi-hop swaps, liquidity provision, and price calculations.
 */
contract UniswapV2Router {
    /*//////////////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////////////*/
    error UniswapV2Router__ZeroAmountIn();
    error UniswapV2Router__ZeroAmountOut();
    error UniswapV2Router__ZeroReserves();
    error UniswapV2Router__InsufficientOutputReserve();

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

    /*//////////////////////////////////////////////////////////////////////
                    EXTERNAL & PUBLIC VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

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
}
