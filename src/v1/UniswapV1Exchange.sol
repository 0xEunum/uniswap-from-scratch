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
    error UniswapV1Exchange__ZeroInputAmount();
    error UniswapV1Exchange__ZeroReserves();
    error UniswapV1Exchange__ZeroOutputAmount();
    error UniswapV1Exchange__InsufficientOutputReserve();
    error UniswapV1Exchange__EthSoldIsZero();
    error UniswapV1Exchange__DeadlineExpired();
    error UniswapV1Exchange__MinTokensIsZero();
    error UniswapV1Exchange__InsufficientTokensBought();
    error UniswapV1Exchange__TokensTransferFailed(address sender, address recipient, uint256 tokensBought);

    /*//////////////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////////////*/
    IERC20 public immutable I_TOKEN;
    address public immutable I_FACTORY;

    /// @notice The multiplier representing (1000 - 3) = 997, accounting for the 0.3% trading fee.
    uint256 private constant FEE_MULTIPLIER = 997;

    /// @notice The fee denominator representing 1000 (100%).
    uint256 private constant FEE_DENOMINATOR = 1000;

    /*//////////////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////////////*/
    event TokenPurchase(address indexed buyer, uint256 ethSold, uint256 tokensBought);

    /*//////////////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////////////*/

    modifier deadlineNotExpired(uint256 _deadline) {
        if (_deadline < block.timestamp) {
            revert UniswapV1Exchange__DeadlineExpired();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the exchange with paired ERC20 token, factory address, and LP token metadata.
     * @param _token The address of the ERC20 token traded on this exchange.
     * @param _factory The address of Uniswap V1 factory.
     * @param _lpTokenName The human-readable name of the Liquidity pool token.
     * @param _lpTokenSymbol The symbol of the Liquidity pool token.
     */
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

    /*//////////////////////////////////////////////////////////////////////
                                EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////
                                PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////
                                PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes an ETH to Token swap.
     * @param _ethSold Amount of ETH sold.
     * @param _minTokens Minimum amount of Tokens bought.
     * @param _deadline Swap deadline timestamp.
     * @param _buyer Address paying ETH.
     * @param _recipient Address receiving Tokens.
     * @return Amount of Tokens bought.
     */
    function _ethToTokenInput(
        uint256 _ethSold,
        uint256 _minTokens,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private deadlineNotExpired(_deadline) returns (uint256) {
        if (_ethSold == 0) {
            revert UniswapV1Exchange__EthSoldIsZero();
        }

        if (_minTokens == 0) {
            revert UniswapV1Exchange__MinTokensIsZero();
        }

        uint256 ethReserve = address(this).balance - _ethSold;
        uint256 tokenReserve = I_TOKEN.balanceOf(address(this));

        uint256 tokensBought = _getInputPrice(_ethSold, ethReserve, tokenReserve);

        if (tokensBought < _minTokens) {
            revert UniswapV1Exchange__InsufficientTokensBought();
        }

        emit TokenPurchase(_buyer, _ethSold, tokensBought);

        bool success = I_TOKEN.transfer(_recipient, tokensBought);
        if (!success) {
            revert UniswapV1Exchange__TokensTransferFailed(address(this), _recipient, tokensBought);
        }

        return tokensBought;
    }

    /*//////////////////////////////////////////////////////////////////////
                    INTERNAL & PRIVATE VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates output amount received given an exact input amount sold.
     * @dev Follows constant product formula (x + Δx * 0.997)(y - Δy) = xy.
     *      Solving for Δy gives Δy = (Δx * 997 * y) / (x * 1000 + Δx * 997).
     * @param _inputAmount Amount of input asset being sold.
     * @param _inputReserve Current reserve of the input asset in the pool.
     * @param _outputReserve Current reserve of the output asset in the pool.
     * @return outputAmount Amount of output asset bought.
     */
    function _getInputPrice(uint256 _inputAmount, uint256 _inputReserve, uint256 _outputReserve)
        private
        pure
        returns (uint256 outputAmount)
    {
        if (_inputAmount == 0) {
            revert UniswapV1Exchange__ZeroInputAmount();
        }

        if (_inputReserve == 0 || _outputReserve == 0) {
            revert UniswapV1Exchange__ZeroReserves();
        }

        uint256 inputAmountWithFee = _inputAmount * FEE_MULTIPLIER;
        uint256 numerator = inputAmountWithFee * _outputReserve;
        uint256 denominator = (_inputReserve * FEE_DENOMINATOR) + inputAmountWithFee;
        return numerator / denominator;
    }

    /**
     * @notice Calculates required input amount to sell given an exact output amount bought.
     * @dev Follows constant product formula (x + Δx * 0.997)(y - Δy) = xy.
     *      Solving for Δx gives Δx = (x * Δy * 1000) / ((y - Δy) * 997).
     *      Adds 1 to round up in favor of the pool, preventing integer truncation loss.
     * @param _outputAmount Desired amount of output asset being bought.
     * @param _inputReserve Current reserve of the input asset in the pool.
     * @param _outputReserve Current reserve of the output asset in the pool.
     * @return inputAmount Amount of input asset required to be sold.
     */
    function _getOutputPrice(uint256 _outputAmount, uint256 _inputReserve, uint256 _outputReserve)
        private
        pure
        returns (uint256 inputAmount)
    {
        if (_outputAmount == 0) {
            revert UniswapV1Exchange__ZeroOutputAmount();
        }

        if (_inputReserve == 0 || _outputReserve == 0) {
            revert UniswapV1Exchange__ZeroReserves();
        }

        if (_outputAmount >= _outputReserve) {
            revert UniswapV1Exchange__InsufficientOutputReserve();
        }

        uint256 numerator = _inputReserve * _outputAmount * FEE_DENOMINATOR;
        uint256 denominator = (_outputReserve - _outputAmount) * FEE_MULTIPLIER;

        return (numerator / denominator) + 1;
    }

    /*//////////////////////////////////////////////////////////////////////
                    EXTERNAL & PUBLIC VIEW & PURE FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns how many tokens are bought for an exact ETH amount.
     * @param _ethSold Amount of ETH sold.
     * @return Amount of tokens bought.
     */
    function getEthToTokenInputPrice(uint256 _ethSold) external view returns (uint256) {
        if (_ethSold == 0) {
            revert UniswapV1Exchange__EthSoldIsZero();
        }

        uint256 ethReserves = address(this).balance;
        uint256 tokenReserves = I_TOKEN.balanceOf(address(this));

        return _getInputPrice(_ethSold, ethReserves, tokenReserves);
    }
}
