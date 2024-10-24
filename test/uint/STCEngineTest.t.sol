// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {STCEngine} from "src/STCEngine.sol";
import {StableCoin} from "src/StableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployStcEngine} from "script/DeployStcEngine.s.sol";
// import {Vm} from "forge-std/Vm.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract STCEngineTest is Test {
    HelperConfig public helperConfig;
    STCEngine stcEngine;
    StableCoin stableCoin;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    address public wethPriceFeed;
    address public wbtcPriceFeed;
    address public weth;
    address public wbtc;

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant ERC20_ETH_BALANCE = 100 ether;

    // make user
    address public USER = makeAddr("user");

    function setUp() public {
        DeployStcEngine deployer = new DeployStcEngine();
        (stcEngine, stableCoin) = deployer.run();

        helperConfig = new HelperConfig();
        (wethPriceFeed, wbtcPriceFeed, weth, wbtc,) = helperConfig.localNetworkConfig();

        ERC20Mock(weth).mint(USER, ERC20_ETH_BALANCE);
        // priceFeedAddresses = [wethPriceFeed, wbtcPriceFeed];
        // tokenAddresses = [weth, wbtc];
        // console.log("setup-WETH address:", weth);
        // console.log("setup-wbtc address:", wbtc);
        // console.log("setup-wethPriceFeed address:", wethPriceFeed);
        // console.log("setup-wbtcPriceFeed address:", wbtcPriceFeed);
    }

    // function testAddresses() public view {
    //     for (uint256 i = 0; i < tokenAddresses.length; i++) {
    //         console.log("test-tokenAddresses at index", i, "is", tokenAddresses[i]);
    //     }
    //     for (uint256 i = 0; i < priceFeedAddresses.length; i++) {
    //         console.log("test-priceFeedAddresses at index", i, "is", priceFeedAddresses[i]);
    //     }
    // }

    /// / / / / / / / / / / / / / / / /
    // constructor function  / / / / /
    /// / / / / / / / / / / / / / / /

    function testRevertIfConstructorInputsDoesnotMatch() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethPriceFeed);
        priceFeedAddresses.push(wbtcPriceFeed);

        vm.expectRevert(STCEngine.STCEngine__tokenAndPricefeedAddressMustHaveSameLength.selector);
        new STCEngine(tokenAddresses, priceFeedAddresses, address(stableCoin));
    }

    /// / / / / / / / / / / / / /
    // Price functions / / / / /
    /// / / / / / / / / / / / / /

    function testGetTokenAmountFromUsd() public {
        uint256 weiAmount = 10 ether;
        // 10e18 / 2600 = 3,846,153,846,153,846
        uint256 expectedAmount = 3846153846153846;

        uint256 actualAmount = stcEngine.getTokenAmountFromUsd(weth, weiAmount);
        assertEq(expectedAmount, actualAmount);
    }

    function testGetPriceInUsd() public view {
        // Check if the price feed is correctly set
        console.log("getpricetest-WETH address:", weth);
        console.log("getpricetest-WETH price feed address:", wethPriceFeed);

        // Get the actual price from the mock price feed
        MockV3Aggregator mockPriceFeed = MockV3Aggregator(wethPriceFeed);
        (, int256 expectedPrice,,,) = mockPriceFeed.latestRoundData();
        console.log("getpricetest-Expected price from mock:", expectedPrice);

        // Get the price from the STCEngine
        int256 actualUsdValue = stcEngine.getPriceInUsd(weth);
        console.log("getpricetest-Actual USD value from STCEngine:", actualUsdValue);

        assertEq(expectedPrice, actualUsdValue, "Price from STCEngine doesn't match mock price feed");
    }

    function testGetConvertedValueInUsd() public view {
        uint256 amount = 1e18;
        uint256 expectedPrice = 2600e18;
        uint256 actualUsdValue = stcEngine.getConvertedValueInUsd(weth, amount);
        console.log("Actual USD value from STCEngine:", actualUsdValue);

        assertEq(expectedPrice, actualUsdValue);
    }

    function testGetPriceFeedAddress() public view {
        // Check if the price feed is correctly set
        console.log("testGetPriceFeedAddress-WETH address:", weth);
        console.log("testGetPriceFeedAddress-WETH price feed address:", wethPriceFeed);
        // Check if the price feed is correctly set
        address expectedwethPriceFeed = stcEngine.getPriceFeedAddress(weth);
        console.log(expectedwethPriceFeed);
        assertEq(expectedwethPriceFeed, wethPriceFeed);
    }

    /// / / / / / / / / / / / / / /  / / / / /
    // depositeCollateral functions / / / / /
    /// / / / / / / / / / / / / /  / / / / /

    function testRevertInZeroCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(stcEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(STCEngine.STCEngine__MorethanZero.selector);
        stcEngine.depositeCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock testToken = new ERC20Mock("test", "test");
        testToken.mint(USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);

        vm.expectRevert(STCEngine.STCEngine__notAllowedToken.selector); // test with inputs
        stcEngine.depositeCollateral(address(testToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(stcEngine), AMOUNT_COLLATERAL);
        stcEngine.depositeCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testGetAccountInfo() public depositCollateral {
        vm.startPrank(USER);
        (uint256 STCMinted, uint256 collateralValueInUsd) = stcEngine.getAccountInformation(USER);

        uint256 expectedSTCMinted = 0;
        uint256 expectedDepositeAmount = stcEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(expectedSTCMinted, STCMinted);
        assertEq(expectedDepositeAmount, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    // function testDepositeCollateral() public{
    //     vm.prank(USER);
    //     uint256 amount = 1e18;
    //     uint256 expectedCollateralValueInUsd = 2600e18;
    //     ERC20Mock(weth).mint(USER, 10E18);
    //     ERC20Mock(weth).approve(address(stcEngine), amount);
    //     ERC20Mock(weth).allowance(USER, address(stcEngine));
    //     stcEngine.depositeCollateral(weth, amount);
    //     uint256 actualCollateralValueInUsd = stcEngine.getCollateralValueInUsd(USER);
    //     console.log("Actual collateral value in USD:", actualCollateralValueInUsd);
    //     assertEq(expectedCollateralValueInUsd, actualCollateralValueInUsd);
    // }
}

/*

// Test: Revert if trying to mint STC with insufficient collateral
    function testRevertOnInsufficientCollateral() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount / 2);  // Only approve half the amount

        vm.expectRevert(STCEngine__InsufficientCollateral.selector);  // Custom error
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        vm.stopPrank();
    }

    // Test: Revert if trying to redeem more collateral than deposited
    function testRevertOnOverRedeemCollateral() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        // Try to redeem more collateral than deposited
        vm.expectRevert(STCEngine__CollateralRedemptionFailed.selector);  // Custom error
        stcEngine.redeemCollateralsForSTC(address(collateralToken), initialCollateralAmount + 1e18, initialMintAmount);

        vm.stopPrank();
    }

    // Test: Revert if minting when health factor is broken
    function testRevertOnBrokenHealthFactor() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        // Simulate price drop to break health factor
        vm.mockCall(address(priceFeed), abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(0, int256(500 * 1e8), 0, 0, 0));

        // Try to mint more STC when health factor is broken
        vm.expectRevert(STCEngine__HealthFactorTooLow.selector);  // Custom error
        stcEngine.mintSTC(1e18);

        vm.stopPrank();
    }

    // Test: Revert if approval for collateral fails
    function testRevertOnApprovalFailure() public {
        vm.startPrank(user);

        // Do not approve any collateral
        vm.expectRevert(STCEngine__TransferAmountExceedsAllowance.selector);  // Custom error
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        vm.stopPrank();
    }

    // Test: Revert if trying to liquidate a healthy position
    function testRevertOnInvalidLiquidationHealthyPosition() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        // Liquidator attempts to liquidate a healthy position
        vm.startPrank(liquidator);
        vm.expectRevert(STCEngine__CannotLiquidateHealthyPosition.selector);  // Custom error
        stcEngine.liquidate(address(collateralToken), user, initialMintAmount);

        vm.stopPrank();
    }

    // Test: Revert if liquidator doesn't have enough STC to cover liquidation
    function testRevertOnInsufficientLiquidatorSTC() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        // Simulate price drop to make position unhealthy
        vm.mockCall(address(priceFeed), abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(0, int256(500 * 1e8), 0, 0, 0));

        // Liquidator has no STC, but tries to liquidate
        vm.startPrank(liquidator);
        vm.expectRevert(STCEngine__InsufficientSTCForLiquidation.selector);  // Custom error
        stcEngine.liquidate(address(collateralToken), user, initialMintAmount);

        vm.stopPrank();
    }

    // Test: Revert if the contract is initialized with a zero address as collateral or price feed
    function testRevertOnZeroAddressInConstructor() public {
        address;
        address;
        tokenAddresses[0] = address(0);  // Invalid zero address
        priceFeedAddresses[0] = address(priceFeed);

        // Expect revert due to zero address input for collateral
        vm.expectRevert(STCEngine__InvalidZeroAddress.selector);  // Custom error
        new STCEngine(tokenAddresses, priceFeedAddresses, address(stableCoin));

        tokenAddresses[0] = address(collateralToken);
        priceFeedAddresses[0] = address(0);  // Invalid zero address for price feed

        // Expect revert due to zero address input for price feed
        vm.expectRevert(STCEngine__InvalidZeroAddress.selector);  // Custom error
        new STCEngine(tokenAddresses, priceFeedAddresses, address(stableCoin));
    }

    // Test: Revert if trying to mint with zero collateral
    function testRevertOnZeroCollateralMinting() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), 0);  // No collateral approved

        // Attempt to mint STC with zero collateral (should revert)
        vm.expectRevert(STCEngine__CollateralAmountMustBeGreaterThanZero.selector);  // Custom error
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), 0, initialMintAmount);

        vm.stopPrank();
    }

    // Test: Revert on minting STC if price feed returns an invalid price (e.g., zero or negative)
    function testRevertOnInvalidPriceFeed() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);

        // Mock invalid price from the price feed (e.g., zero price)
        vm.mockCall(address(priceFeed), abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(0, int256(0), 0, 0, 0));

        vm.expectRevert(STCEngine__InvalidPriceFeed.selector);  // Custom error
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        vm.stopPrank();
    }


    // Test: Constructor should initialize state variables correctly
    function testConstructorInitializesCorrectly() public {
        // Check if the price feed is correctly mapped to the collateral token
        address feedAddress = stcEngine.getPriceFeedAddress(address(collateralToken));
        assertEq(feedAddress, address(priceFeed), "Price feed should match the one provided");

        // Check the StableCoin address initialization
        address stableCoinAddress = address(stcEngine.i_STC());
        assertEq(stableCoinAddress, address(stableCoin), "StableCoin address should match the one provided");
    }

    // Test: Constructor should fail if token and priceFeed lengths don't match
    function testFail_ConstructorRevertsOnMismatchedInputLengths() public {
        address;
        address;  // Mismatch

        // This should fail due to length mismatch
        new STCEngine(tokenAddresses, priceFeedAddresses, address(stableCoin));
    }

    // Test: Deposit collateral and mint STC
    function testDepositCollateralAndMintSTC() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        (uint256 minted, uint256 collateralValueInUsd) = stcEngine.getAccountInformation(user);
        assertEq(minted, initialMintAmount, "Minted STC mismatch");
        assertGt(collateralValueInUsd, 0, "Collateral value should be greater than 0");

        vm.stopPrank();
    }

    // Test: Redeem collateral and burn STC
    function testRedeemCollateralAndBurnSTC() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        stcEngine.redeemCollateralsForSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        (uint256 minted, uint256 collateralValueInUsd) = stcEngine.getAccountInformation(user);
        assertEq(minted, 0, "Minted STC should be 0 after burning");
        assertEq(collateralValueInUsd, 0, "Collateral value should be 0 after redeem");

        vm.stopPrank();
    }

    // Test: Fail deposit due to insufficient collateral balance
    function testFail_DepositWithInsufficientBalance() public {
        vm.startPrank(user);

        uint256 excessCollateralAmount = initialCollateralAmount + 1e18;
        collateralToken.approve(address(stcEngine), excessCollateralAmount);

        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), excessCollateralAmount, initialMintAmount);

        vm.stopPrank();
    }

    // Test: Liquidate an unhealthy position
    function testLiquidateUnhealthyPosition() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        // Simulate price drop
        vm.mockCall(address(priceFeed), abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(0, int256(500 * 1e8), 0, 0, 0));

        address liquidator = address(0xdead);
        vm.startPrank(liquidator);
        stcEngine.liquidate(address(collateralToken), user, initialMintAmount);

        (uint256 minted, ) = stcEngine.getAccountInformation(user);
        assertEq(minted, 0, "User's STC should be 0 after liquidation");

        vm.stopPrank();
    }

    // Test: Fail minting when health factor is broken (i.e., undercollateralized)
    function testFail_MintWhenHealthFactorIsBroken() public {
        vm.startPrank(user);

        // Mock price drop to break the health factor
        vm.mockCall(address(priceFeed), abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector), abi.encode(0, int256(500 * 1e8), 0, 0, 0));

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        // Try minting more STC when health factor is already broken (should fail)
        stcEngine.mintSTC(1e18);

        vm.stopPrank();
    }

    // Test: Get health factor after collateral deposit
    function testHealthFactor() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        uint256 healthFactor = stcEngine.getHealthFactor();
        assertGt(healthFactor, 1e18, "Health factor should be greater than 1");

        vm.stopPrank();
    }

    // Test: Ensure internal functions (indirect test via public functions)
    function testInternalFunctionsIndirectly() public {
        vm.startPrank(user);

        collateralToken.approve(address(stcEngine), initialCollateralAmount);
        stcEngine.depositeCollateralAndMintSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        // The redeemCollateral and burnSTC will internally call `_redeemCollateral` and `_burnSTC`
        stcEngine.redeemCollateralsForSTC(address(collateralToken), initialCollateralAmount, initialMintAmount);

        (uint256 minted, uint256 collateralValueInUsd) = stcEngine.getAccountInformation(user);
        assertEq(minted, 0, "Minted STC should be 0 after burning");
        assertEq(collateralValueInUsd, 0, "Collateral value should be 0 after redeem");

        vm.stopPrank();
    }

    // Test: Get price feed address
    function testGetPriceFeedAddress() public {
        address feedAddress = stcEngine.getPriceFeedAddress(address(collateralToken));
        assertEq(feedAddress, address(priceFeed), "Price feed should match the one provided");
    }
*/
