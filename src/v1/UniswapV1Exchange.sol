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
 * @dev Inherits OpenZeppelin ERC20 to issue LP (Liquidity Provider) tokens representing pooled shares.
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
    error UniswapV1Exchange__InvalidRecipient();
    error UniswapV1Exchange__TokensBoughtIsZero();
    error UniswapV1Exchange__MaxEthIsZero();
    error UniswapV1Exchange__EthSoldExceedsMaxEth();
    error UniswapV1Exchange__EthTransferFailed(address buyer, uint256 amount);
    error UniswapV1Exchange__MaxTokensIsZero();
    error UniswapV1Exchange__InsufficientEthAmount();
    error UniswapV1Exchange__MinLiquidityIsZero();
    error UniswapV1Exchange__MaxTokensExceeded();
    error UniswapV1Exchange__InsufficientLiquidityMinted();

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
    event AddLiquidity(address indexed provider, uint256 ethAmount, uint256 tokenAmount);

    /*//////////////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////////////*/

    /// @notice Reverts if the transaction execution deadline has passed.
    /// @param _deadline Timestamp after which transaction expires.
    modifier deadlineNotExpired(uint256 _deadline) {
        if (_deadline < block.timestamp) {
            revert UniswapV1Exchange__DeadlineExpired();
        }
        _;
    }

    /// @notice Validates that the recipient is neither address(0) nor this exchange contract.
    /// @param _recipient The address to validate.
    modifier validRecipient(address _recipient) {
        if (_recipient == address(0) || _recipient == address(this)) {
            revert UniswapV1Exchange__InvalidRecipient();
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

    /**
     * @notice Deposits ETH and tokens into the exchange pool and mints LP tokens to msg.sender.
     * @dev If liquidity already exists, deposited tokens must match the current pool price ratio.
     *      If this is the initial deposit, `_maxTokens` determines the initial token reserve.
     * @param _minLiquidity Minimum amount of LP tokens caller expects to receive (slippage check).
     * @param _maxTokens Maximum amount of tokens caller is willing to deposit.
     * @param _deadline Timestamp after which transaction reverts.
     * @return liquidityMinted Amount of LP tokens minted to caller.
     */
    function addLiquidity(uint256 _minLiquidity, uint256 _maxTokens, uint256 _deadline)
        external
        payable
        deadlineNotExpired(_deadline)
        returns (uint256)
    {
        if (_maxTokens == 0) {
            revert UniswapV1Exchange__MaxTokensIsZero();
        }

        if (msg.value == 0) {
            revert UniswapV1Exchange__InsufficientEthAmount();
        }

        uint256 totalLiquidity = totalSupply();

        if (totalLiquidity > 0) {
            if (_minLiquidity == 0) {
                revert UniswapV1Exchange__MinLiquidityIsZero();
            }

            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = I_TOKEN.balanceOf(address(this));

            uint256 tokenAmount = msg.value * tokenReserve / ethReserve + 1;

            uint256 liquidityMinted = msg.value * totalLiquidity / ethReserve;

            if (_maxTokens < tokenAmount) {
                revert UniswapV1Exchange__MaxTokensExceeded();
            }

            if (liquidityMinted < _minLiquidity) {
                revert UniswapV1Exchange__InsufficientLiquidityMinted();
            }

            _mint(msg.sender, liquidityMinted);

            bool success = I_TOKEN.transferFrom(msg.sender, address(this), tokenAmount);
            if (!success) {
                revert UniswapV1Exchange__TokensTransferFailed(msg.sender, address(this), tokenAmount);
            }

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);

            return liquidityMinted;
        } else {
            if (msg.value < 1_000_000_000) {
                revert UniswapV1Exchange__InsufficientEthAmount();
            }
            uint256 tokenAmount = _maxTokens;
            uint256 initialLiquidity = address(this).balance;

            _mint(msg.sender, initialLiquidity);

            bool success = I_TOKEN.transferFrom(msg.sender, address(this), tokenAmount);
            if (!success) {
                revert UniswapV1Exchange__TokensTransferFailed(msg.sender, address(this), tokenAmount);
            }

            emit AddLiquidity(msg.sender, msg.value, tokenAmount);

            return initialLiquidity;
        }
    }

    /**
     * @notice Swaps ETH for tokens and transfers them to msg.sender.
     * @param _minTokens Minimum amount of tokens caller expects to receive (slippage protection).
     * @param _deadline Timestamp after which transaction reverts.
     * @return tokensBought The amount of tokens purchased and transferred to msg.sender.
     */
    function ethToTokenSwapInput(uint256 _minTokens, uint256 _deadline)
        external
        payable
        returns (uint256 tokensBought)
    {
        return _ethToTokenInput(msg.value, _minTokens, _deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Converts ETH to an exact amount of tokens and transfers them to msg.sender.
     * @param _tokensBought Exact amount of tokens caller wants to purchase.
     * @param _deadline Timestamp after which transaction reverts.
     * @return ethSold The amount of ETH sold for the requested tokens.
     */
    function ethToTokenSwapOutput(uint256 _tokensBought, uint256 _deadline) external payable returns (uint256 ethSold) {
        return _ethToTokenOutput(_tokensBought, msg.value, _deadline, msg.sender, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////////////
                                PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Swaps ETH for tokens and transfers them to a specified recipient.
     * @param _minTokens Minimum amount of tokens recipient must receive (slippage protection).
     * @param _deadline Timestamp after which transaction reverts.
     * @param _recipient The address receiving the purchased tokens.
     * @return tokensBought The amount of tokens purchased and transferred to recipient.
     */
    function ethToTokenTransferInput(uint256 _minTokens, uint256 _deadline, address _recipient)
        public
        payable
        validRecipient(_recipient)
        returns (uint256 tokensBought)
    {
        return _ethToTokenInput(msg.value, _minTokens, _deadline, msg.sender, _recipient);
    }

    /**
     * @notice Converts ETH to an exact amount of tokens and transfers them to a specified recipient.
     * @param _tokensBought Exact amount of tokens recipient will receive.
     * @param _deadline Timestamp after which transaction reverts.
     * @param _recipient Address receiving the purchased tokens.
     * @return ethSold The amount of ETH sold for the requested tokens.
     */
    function ethToTokenTransferOutput(uint256 _tokensBought, uint256 _deadline, address _recipient)
        public
        payable
        validRecipient(_recipient)
        returns (uint256 ethSold)
    {
        return _ethToTokenOutput(_tokensBought, msg.value, _deadline, msg.sender, _recipient);
    }

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

        bool success = I_TOKEN.transfer(_recipient, tokensBought);
        if (!success) {
            revert UniswapV1Exchange__TokensTransferFailed(address(this), _recipient, tokensBought);
        }

        emit TokenPurchase(_buyer, _ethSold, tokensBought);

        return tokensBought;
    }

    /**
     * @notice Converts ETH to an exact amount of tokens and refunds any unused ETH.
     * @param _tokensBought Exact amount of tokens bought.
     * @param _maxEth Maximum amount of ETH the buyer is willing to spend.
     * @param _deadline Timestamp after which transaction reverts.
     * @param _buyer Address paying ETH and receiving the refund.
     * @param _recipient Address receiving the purchased tokens.
     * @return ethSold Amount of ETH sold.
     */
    function _ethToTokenOutput(
        uint256 _tokensBought,
        uint256 _maxEth,
        uint256 _deadline,
        address _buyer,
        address _recipient
    ) private deadlineNotExpired(_deadline) returns (uint256 ethSold) {
        if (_tokensBought == 0) {
            revert UniswapV1Exchange__TokensBoughtIsZero();
        }

        if (_maxEth == 0) {
            revert UniswapV1Exchange__MaxEthIsZero();
        }

        uint256 ethReserve = address(this).balance - _maxEth;
        uint256 tokenReserve = I_TOKEN.balanceOf(address(this));

        ethSold = _getOutputPrice(_tokensBought, ethReserve, tokenReserve);

        if (ethSold > _maxEth) {
            revert UniswapV1Exchange__EthSoldExceedsMaxEth();
        }

        uint256 ethRefund = _maxEth - ethSold;

        if (ethRefund > 0) {
            (bool success,) = payable(_buyer).call{value: ethRefund}("");
            if (!success) {
                revert UniswapV1Exchange__EthTransferFailed(_buyer, ethRefund);
            }
        }

        bool tokenTransferSuccess = I_TOKEN.transfer(_recipient, _tokensBought);
        if (!tokenTransferSuccess) {
            revert UniswapV1Exchange__TokensTransferFailed(address(this), _recipient, _tokensBought);
        }

        emit TokenPurchase(_buyer, ethSold, _tokensBought);

        return ethSold;
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
     * @notice Calculates output amount received given an exact input amount sold.
     * @param _inputAmount Amount of input asset being sold.
     * @param _inputReserve Current reserve of the input asset in the pool.
     * @param _outputReserve Current reserve of the output asset in the pool.
     * @return outputAmount Amount of output asset bought.
     */
    function getInputPrice(uint256 _inputAmount, uint256 _inputReserve, uint256 _outputReserve)
        external
        pure
        returns (uint256 outputAmount)
    {
        return _getInputPrice(_inputAmount, _inputReserve, _outputReserve);
    }

    /**
     * @notice Calculates required input amount to sell given an exact output amount bought.
     * @param _outputAmount Desired amount of output asset being bought.
     * @param _inputReserve Current reserve of the input asset in the pool.
     * @param _outputReserve Current reserve of the output asset in the pool.
     * @return inputAmount Amount of input asset required to be sold.
     */
    function getOutputPrice(uint256 _outputAmount, uint256 _inputReserve, uint256 _outputReserve)
        external
        pure
        returns (uint256 inputAmount)
    {
        return _getOutputPrice(_outputAmount, _inputReserve, _outputReserve);
    }

    /**
     * @notice Returns how many tokens are bought for an exact ETH amount.
     * @param _ethSold Amount of ETH sold.
     * @return tokensBought Amount of tokens bought.
     */
    function getEthToTokenInputPrice(uint256 _ethSold) external view returns (uint256 tokensBought) {
        if (_ethSold == 0) {
            revert UniswapV1Exchange__EthSoldIsZero();
        }

        uint256 ethReserve = address(this).balance;
        uint256 tokenReserves = I_TOKEN.balanceOf(address(this));

        return _getInputPrice(_ethSold, ethReserve, tokenReserves);
    }

    /**
     * @notice Returns how much ETH is required to buy an exact amount of tokens.
     * @param _tokensBought Desired amount of tokens to buy.
     * @return ethSold Amount of ETH required to buy the requested tokens.
     */
    function getEthToTokenOutputPrice(uint256 _tokensBought) external view returns (uint256 ethSold) {
        if (_tokensBought == 0) {
            revert UniswapV1Exchange__TokensBoughtIsZero();
        }

        uint256 ethReserve = address(this).balance;
        uint256 tokenReserves = I_TOKEN.balanceOf(address(this));

        return _getOutputPrice(_tokensBought, ethReserve, tokenReserves);
    }
}
