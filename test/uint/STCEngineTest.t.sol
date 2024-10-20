// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {STCEngine} from "src/STCEngine.sol";
import {StableCoin} from "src/StableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployStcEngine} from "script/DeployStcEngine.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract CounterTest is Test {
    HelperConfig public helperConfig;
    STCEngine stcEngine;
    StableCoin stableCoin;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    address wethPriceFeed;
    address wbtcPriceFeed;
    address weth;
    address wbtc;

    // make user
    address public USER = makeAddr("user");

    function setUp() public {
        DeployStcEngine deployer = new DeployStcEngine();
        (stcEngine , stableCoin) = deployer.run();

        helperConfig = new HelperConfig();
        (wethPriceFeed, wbtcPriceFeed, weth, wbtc, ) =
            helperConfig.localNetworkConfig();
        priceFeedAddresses = [wethPriceFeed , wbtcPriceFeed];
        tokenAddresses =[weth , wbtc];
    }
    
    /// / / / / / / / / / / / / /
    // Price functions / / / / /
    /// / / / / / / / / / / / / /

    function testGetPriceInUsd() public view{
        // Check if the price feed is correctly set
        console.log("WETH address:", weth);
        console.log("WETH price feed address:", wethPriceFeed);

        // Get the actual price from the mock price feed
        MockV3Aggregator mockPriceFeed = MockV3Aggregator(wethPriceFeed);
        (, int256 expectedPrice,,,) = mockPriceFeed.latestRoundData();
        console.log("Expected price from mock:", expectedPrice);

        // Get the price from the STCEngine
        int256 actualUsdValue = stcEngine.getPriceInUsd(wethPriceFeed);
        console.log("Actual USD value from STCEngine:", actualUsdValue);

        assertEq(expectedPrice, actualUsdValue, "Price from STCEngine doesn't match mock price feed");
    }
    
    function testGetConvertedValueInUsd() public view{
        uint256 amount = 1e18;
        uint256 expectedPrice = 2600e18;
        uint256 actualUsdValue = stcEngine.getConvertedValueInUsd(wethPriceFeed,amount);
        console.log("Actual USD value from STCEngine:", actualUsdValue);
    
        assertEq(expectedPrice, actualUsdValue);
        
    }
    function testGetPriceFeedAddress() public view{
         // Check if the price feed is correctly set
        console.log("WETH address:", weth);
        console.log("WETH price feed address:", wethPriceFeed);
        // Check if the price feed is correctly set
        address expectedwethPriceFeed =stcEngine.getPriceFeedAddress(weth);
        console.log(expectedwethPriceFeed);
        assertEq(expectedwethPriceFeed, wethPriceFeed);
    }

    /// / / / / / / / / / / / / /
    // depositeCollateral functions / / / / /
    /// / / / / / / / / / / / / /

    function testDepositeCollateral() public{
        vm.prank(USER);
        uint256 amount = 1e18;
        uint256 expectedCollateralValueInUsd = 2600e18;
        ERC20Mock(weth).approve(address(stcEngine), amount);
        stcEngine.depositeCollateral(weth, amount);
        uint256 actualCollateralValueInUsd = stcEngine.getCollateralValueInUsd(USER);
        console.log("Actual collateral value in USD:", actualCollateralValueInUsd);
        assertEq(expectedCollateralValueInUsd, actualCollateralValueInUsd);
    }

}
