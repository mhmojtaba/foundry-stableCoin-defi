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
    error STCEngine__MorethanZero();
    error STCEngine__notAllowedToken();
    error STCEngine__tokenAndPricefeedAddressMustHaveSameLength();
    error STCEngine__tokenTransferFailed();
    error STCEngine__Insufficientbalance();
    error STCEngine__MintFailed();
    error STCEngine__HealthFactorIsBroken(uint256 userHealthFactor);
    error STCEngine__validHealthFactor();
    error STCEngine__HealthFactorNotImproved();

    /// / / / / / / / / / / / / /
    // state variables / / / / /
    /// / / / / / / / / / / / / /
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10 percent bonus to liquidator
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralized
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1e18; // minimum health factor

    mapping(address token => address priceFeed) private s_priceFeedsToken; // token to pricefeed
    mapping(address user => mapping(address token => uint256 amount)) private s_tokenCollateralDeposited; // how much of a specific token deposited by user
    mapping(address user => uint256 STCMinted) private s_STCMinted;

    address[] private s_collateralTokens;
    StableCoin private immutable i_STC;

    /// / / / / / / / / / / / / /
    // events / / / / /
    /// / / / / / / / / / / / / /
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeeemed(address indexed from, address indexed to, address indexed token, uint256 amount);

    // modifires / / / / /
    /// / / / / / / / / / / / / /
    modifier moreThanzero(uint256 amount) {
        if (amount == 0) {
            revert STCEngine__MorethanZero();
        }
        _;
    }

    modifier tokenAllowed(address token) {
        if (s_priceFeedsToken[token] == address(0)) {
            revert STCEngine__notAllowedToken();
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
    function depositeCollateralAndMintSTC(address tokenCollateralAddress, uint256 collateralAmount, uint256 stcToMint)
        external
    {
        depositeCollateral(tokenCollateralAddress, collateralAmount);
        mintSTC(stcToMint);
    }

    /// @notice deposit collateral tokens
    /// @param tokenCollateralAddress the address of token to deposite as collateral
    /// @param collateralAmount the amount of token to deposite
    function depositeCollateral(address tokenCollateralAddress, uint256 collateralAmount)
        public
        moreThanzero(collateralAmount)
        tokenAllowed(tokenCollateralAddress)
        nonReentrant
    {
        s_tokenCollateralDeposited[msg.sender][tokenCollateralAddress] += collateralAmount; // update mapping
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, collateralAmount);

        uint256 collateralAmountDepositedByUser = s_tokenCollateralDeposited[msg.sender][tokenCollateralAddress];
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
    }

    function redeemCollateralsForSTC(address tokenCollateral, uint256 collateralAmount, uint256 stcAmount) external {
        burnSTC(stcAmount);
        redeemCollateral(tokenCollateral, collateralAmount);
    }

    /// @notice redeem collateral for STC
    /// @dev Explain to a developer any extra details
    /// @param tokenCollateral  the address of collateral token
    /// @param collateralAmount the amount of collateral token to redeem
    /// @notice health factor must be over 1 after collateral pulled out
    function redeemCollateral(address tokenCollateral, uint256 collateralAmount)
        public
        moreThanzero(collateralAmount)
        nonReentrant
        tokenAllowed(tokenCollateral)
    {
        _redeemCollateral(tokenCollateral, msg.sender, msg.sender, collateralAmount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnSTC(uint256 amount) public moreThanzero(amount) {
        _burnSTC(msg.sender, msg.sender, amount);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /// @notice mintSTC ! they must have more collateral value than min threshold
    /// @param amountSTC the amount of STc token
    ///
    function mintSTC(uint256 amountSTC) public moreThanzero(amountSTC) nonReentrant {
        s_STCMinted[msg.sender] += amountSTC; // update state

        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = i_STC.mint(msg.sender, amountSTC);
        if (!success) {
            revert STCEngine__MintFailed();
        }
    }

    /// @notice if we do start nearing undercollateralization, we neeed someone to liquidate
    /// @dev must remove someones position to avoid getting undercollateralization
    /// @param collateral is the address of erc20 collateral token
    /// @param user is the user to liquidate who has broken the health factor
    /// @param amount is the amount of STC we need to burn and liquid
    /// @notice you get bounos for taking the users funds
    /// @notice this function is working assumes the protocol will be roughly 200% overcollateralized in order to work

    function liquidate(address collateral, address user, uint256 amount) external moreThanzero(amount) nonReentrant {
        // check the health factor of the user to liquidate
        uint256 startingUserHealthfactor = _healthFactor(user);
        if (startingUserHealthfactor >= MINIMUM_HEALTH_FACTOR) {
            revert STCEngine__validHealthFactor();
        }
        // take collateral
        uint256 amountTokenCovered = getTokenAmountFromUsd(collateral, amount);

        uint256 bonusCollateral = (amountTokenCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToReedem = amountTokenCovered + bonusCollateral;
        _redeemCollateral(collateral, user, msg.sender, totalCollateralToReedem);

        // burn STC
        _burnSTC(user, msg.sender, amount);

        uint256 endingUserHealthfactor = _healthFactor(user);
        if (endingUserHealthfactor <= startingUserHealthfactor) {
            revert STCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {
        uint256 healthfactor = _healthFactor(msg.sender);
    }

    /// / / / / / / / / / / / / /
    // internal functions / / / / /
    /// / / / / / / / / / / / / /

    function _burnSTC(address targetUser, address stcFrom, uint256 StcToBurn) internal {
        s_STCMinted[targetUser] -= StcToBurn;
        bool success = i_STC.transferFrom(stcFrom, address(this), StcToBurn);
        if (!success) {
            revert STCEngine__tokenTransferFailed();
        }
        i_STC.burn(StcToBurn);
    }

    function _redeemCollateral(address tokenCollateral, address from, address to, uint256 collateralAmount) internal {
        unchecked {
            
            s_tokenCollateralDeposited[from][tokenCollateral] -= collateralAmount;
        }
        emit CollateralRedeeemed(from, to, tokenCollateral, collateralAmount);
        bool success = IERC20(tokenCollateral).transfer(to, collateralAmount);
        if (!success) {
            revert STCEngine__tokenTransferFailed();
        }
    }

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
        return _calculateHealthFactor(STCMinted, collateralValueInUsd);
    }

    function _calculateHealthFactor(uint256 STCMinted, uint256 collateralValueInUsd) internal pure returns (uint256) {
        if (STCMinted == 0) return type(uint256).max;
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
            collateralValueInUsd += getConvertedValueInUsd(token, amountCollateralDepositedByUser);
        }
        return collateralValueInUsd;
    }

    function getConvertedValueInUsd(address token, uint256 amount) public view returns (uint256) {
        int256 price = getPriceInUsd(token);
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getPriceInUsd(address token) public view returns (int256) {
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
        return answer;
    }

    /// / / / / / / / / / / / / /
    // view functions / / / / /
    /// / / / / / / / / / / / / /
    function getPriceFeedAddress(address token) public view returns (address) {
        return s_priceFeedsToken[token];
    }

    function getTokenAmountFromUsd(address collateral, uint256 weiAmount)
        public
        view
        returns (uint256 amountTokenCovered)
    {
        int256 price = getPriceInUsd(collateral);
        amountTokenCovered = (weiAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInformation(address user)
        public
        view
        returns (uint256 STCMinted, uint256 collateralValueInUsd)
    {
        (STCMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function calculateHealthFactor(uint256 STCMinted, uint256 collateralValueInUsd) public pure returns (uint256) {
        return _calculateHealthFactor(STCMinted, collateralValueInUsd);
    }

    function getCollateralAddress() public view returns (address[] memory) {
        return s_collateralTokens;
    }

        function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MINIMUM_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getStablecoin() external view returns (address) {
        return address(i_STC);
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeedsToken[token];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_tokenCollateralDeposited[user][token];
    }
}
