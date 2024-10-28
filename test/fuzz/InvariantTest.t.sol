// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {STCEngine} from "src/STCEngine.sol";
import {StableCoin} from "src/StableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployStcEngine} from "script/DeployStcEngine.s.sol";
// import {Vm} from "forge-std/Vm.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Handler} from "./Handler.t.sol";

// what are invariants?
// 1. the total supply of STC should always be less than total supply of collaterals
// 2. getter functions should never revert

contract InvariantTest is StdInvariant, Test {
    HelperConfig public helperConfig;
    STCEngine stcEngine;
    StableCoin stableCoin;
    Handler handler;
    address public wethPriceFeed;
    address public wbtcPriceFeed;
    address public weth;
    address public wbtc;

    // uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    // uint256 public constant ERC20_ETH_BALANCE = 100 ether;

    // // make user
    // address public USER = makeAddr("user");

    function setUp() public {
        DeployStcEngine deployer = new DeployStcEngine();
        (stcEngine, stableCoin) = deployer.run();
        helperConfig = new HelperConfig();
        (wethPriceFeed, wbtcPriceFeed, weth, wbtc,) = helperConfig.localNetworkConfig();

        handler = new Handler(stcEngine, stableCoin);
        targetContract(address(handler));


        // ERC20Mock(weth).mint(USER, ERC20_ETH_BALANCE);
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // getting total supply of STC and compare it with collateral
        uint256 StcSupply = stableCoin.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(stcEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(stcEngine));
        uint256 wethValue = stcEngine.getConvertedValueInUsd(weth, totalWethDeposited);
        uint256 wbtcValue = stcEngine.getConvertedValueInUsd(wbtc, totalWbtcDeposited);
        console.log("OpenInvariantTest__StcSupply:", StcSupply);
        console.log("OpenInvariantTest__totalWethDeposited:", totalWethDeposited);
        console.log("OpenInvariantTest__totalWbtcDeposited:", totalWbtcDeposited);
        console.log("OpenInvariantTest__wethValue:", wethValue);
        console.log("OpenInvariantTest__wbtcValue:", wbtcValue);
        console.log("OpenInvariantTest__mint called:", handler.timesMintIsCalled());

        assert(StcSupply <= totalWethDeposited + totalWbtcDeposited);
    }

    function invariant_gettersShouldnotRevert() public view {
        // all geter functions
        stcEngine.getConvertedValueInUsd(weth, 1e18);
        stcEngine.getAdditionalFeedPrecision();
        stcEngine.getTokenAmountFromUsd(weth, 1e18);
        stcEngine.getCollateralValueInUsd(msg.sender);
        stcEngine.getPriceInUsd(weth);
        stcEngine.getAccountInformation(msg.sender);
        stcEngine.getStablecoin();
        stcEngine.getCollateralTokens();
        stcEngine.getMinHealthFactor();
        stcEngine.getLiquidationPrecision();
        stcEngine.getLiquidationBonus();
        stcEngine.getLiquidationThreshold();
        stcEngine.getAdditionalFeedPrecision();
        stcEngine.getPrecision();
        stcEngine.getCollateralAddress();


    }
}
