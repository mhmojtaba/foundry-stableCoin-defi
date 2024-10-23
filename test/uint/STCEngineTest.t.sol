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

contract CounterTest is Test {
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
    uint256 public constant ERC20_ETH_BALANCE = 10 ether;

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

    function testAddresses() public view {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            console.log("test-tokenAddresses at index", i, "is", tokenAddresses[i]);
        }
        for (uint256 i = 0; i < priceFeedAddresses.length; i++) {
            console.log("test-priceFeedAddresses at index", i, "is", priceFeedAddresses[i]);
        }
    }

    /// / / / / / / / / / / / / /
    // Price functions / / / / /
    /// / / / / / / / / / / / / /

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
