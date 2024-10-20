// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StableCoin} from "./StableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title StableCOin engine STCEngine
/// @author MojtabaWeb3
/// this system have 1 token equals 1 $ value.
/// this system have 1 token equals 1 $ value.
/// this system should always be "overcollateralized". at no point, should the value of all collaterals <= the backed value of all STC.
/// @notice this contract is similar to DAI if DAI had no governance, no fees and was only backed by wETH and wBTC
/// @notice this contract is the core of STC sysatem and handles all logics such as minting, burning, depositing collaterals and withdrawing.
/// @dev this contract is erc20 implementation of our sable coin system.

contract STCEngine is ReentrancyGuard {
    /// / / / / / / / / / / / / /
    // errors / / / / /
    /// / / / / / / / / / / / / /
    error STCEngine__MorethanZero(uint256 amount);
    error STCEngine__notAllowedToken(address token);
    error STCEngine__tokenAndPricefeedAddressMustHaveSameLength();
    error STCEngine__tokenTransferFailed();
    error STCEngine__Insufficientbalance();
    error STCEngine__TransferAmountExceedsBalance();
    error STCEngine__MintFailed();
    error STCEngine__HealthFactorIsBroken(uint256 userHealthFactor);

    /// / / / / / / / / / / / / /
    // state variables / / / / /
    /// / / / / / / / / / / / / /
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1; // minimum health factor

    mapping(address token => address priceFeed) private s_priceFeedsToken; // token to pricefeed
    mapping(address user => mapping(address token => uint256 amount)) private s_tokenCollateralDeposited; // how much of a specific token deposited by user
    mapping(address user => uint256 STCMinted) private s_STCMinted;

    address[] private s_collateralTokens;
    StableCoin private immutable i_STC;

    /// / / / / / / / / / / / / /
    // events / / / / /
    /// / / / / / / / / / / / / /
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    // modifires / / / / /
    /// / / / / / / / / / / / / /
    modifier moreThanzero(uint256 amount) {
        if (amount == 0) {
            revert STCEngine__MorethanZero(amount);
        }
        _;
    }

    modifier tokenAllowed(address token) {
        if (s_priceFeedsToken[token] == address(0)) {
            revert STCEngine__notAllowedToken(token);
        }
        _;
    }

    // functions//
    ///
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address StcAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert STCEngine__tokenAndPricefeedAddressMustHaveSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeedsToken[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_STC = StableCoin(StcAddress);
    }

    /// / / / / / / / / / / / / /
    // external functions / / / / /
    /// / / / / / / / / / / / / /
    function depositeCollateralAndMintSTC() external {}

    /// @notice deposit collateral tokens
    /// @param tokenCollateralAddress the address of token to deposite as collateral
    /// @param collateralAmount the amount of token to deposite
    function depositeCollateral(address tokenCollateralAddress, uint256 collateralAmount)
        external
        moreThanzero(collateralAmount)
        tokenAllowed(tokenCollateralAddress)
        nonReentrant
    {
        s_tokenCollateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmount; // update mapping
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, collateralAmount);

        uint256 collateralAmountDepositedByUser = s_tokenCollateralDeposited[msg.sender][tokenCollateralAddress];

        // checking user balance before transaction
        if (IERC20(tokenCollateralAddress).balanceOf(msg.sender) >= collateralAmountDepositedByUser) {
            revert STCEngine__Insufficientbalance();
        }

        // transfer token from user to this contract
        // the first way -> call the function in low level call
        (bool success, bytes memory data) = address(IERC20(tokenCollateralAddress)).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), collateralAmount)
        );
        if (!success && !(data.length == 0 || abi.decode(data, (bool)))) {
            revert STCEngine__tokenTransferFailed();
        }
        /*
        / Alternative way -> use a third party library /
        * SafeERC20.safeTransferFrom(IERC20(tokenCollateralAddress), msg.sender, address(this), collateralAmount);
        */

        // checking the contract balance after transfering
        if (IERC20(tokenCollateralAddress).balanceOf(address(this)) >= collateralAmountDepositedByUser) {
            revert STCEngine__TransferAmountExceedsBalance();
        }
    }

    function redeemCollateralsForSTC() external {}
    function redeemCollateral() external {}
    function burnSTC() external {}

    /// @notice mintSTC ! they must have more collateral value than min threshold
    /// @param amountSTC the amount of STc token
    ///
    function minSTC(uint256 amountSTC) external moreThanzero(amountSTC) nonReentrant {
        s_STCMinted[msg.sender] += amountSTC; // update state

        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_STC.mint(msg.sender, amountSTC);
        if (!success) {
            revert STCEngine__MintFailed();
        }
    }

    function liquidate() external {}
    function getHealthFactor() external view {}

    /// / / / / / / / / / / / / /
    // internal functions / / / / /
    /// / / / / / / / / / / / / /

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 STCMinted, uint256 collateralValueInUsd)
    {
        STCMinted = s_STCMinted[user];
        collateralValueInUsd = getCollateralValueInUsd(user);
    }

    /// @notice get the ratio of collateral to STC minted that the user can have by the total STCminted and toal collateral value
    /// @dev if the user get below 1, they can get liquidated
    /// @param user who is checking for liquidation
    /// @return how close the user to get liquidation
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 STCMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / STCMinted;
    }

    /// @notice check if the amount of mintedSTC is not bigger than the amount which must be minted due to amount of collaterals deposited
    /// @dev the health factor based on aave docs
    /// @param user balance that deposited to check the amount of collaterals and amount of token minted
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        // if the amount is less than 1, the user can get liquidated
        if (userHealthFactor < MINIMUM_HEALTH_FACTOR) {
            revert STCEngine__HealthFactorIsBroken(userHealthFactor);
        }
    }

    /// / / / / / / / / / / / / /
    // public functions / / / / /
    /// / / / / / / / / / / / / /

    function getCollateralValueInUsd(address user) public view returns (uint256 collateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amountCollateralDepositedByUser = s_tokenCollateralDeposited[user][token];
            collateralValueInUsd += getValueInUsd(token, amountCollateralDepositedByUser);
        }
        return collateralValueInUsd;
    }

    function getValueInUsd(address token, uint256 amount) public view returns (uint256 convertedValue) {
        // using aggrigratorV3Interface
        AggregatorV3Interface dataFeed = AggregatorV3Interface(s_priceFeedsToken[token]);
        (
            /* uint80 roundID */
            ,
            int256 answer,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();
        convertedValue = (amount * (uint256(answer) * ADDITIONAL_FEED_PRECISION)) / PRECISION;
    }
}
