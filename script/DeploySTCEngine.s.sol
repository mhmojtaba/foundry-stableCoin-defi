// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {STCEngine} from "src/STCEngine.sol";
import {StableCoin} from "src/StableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployStcEngine is Script {
    STCEngine stcEngine;
    StableCoin stableCoin;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function setUp() public {
        // HelperConfig helperConfig = new HelperConfig();
        // priceFeedAddresses.push(helperConfig.localNetworkConfig.wethPriceFeed);
        // priceFeedAddresses.push(helperConfig.localNetworkConfig.wbtcPriceFeed);
        // tokenAddresses.push(helperConfig.localNetworkConfig.weth);
        // tokenAddresses.push(helperConfig.localNetworkConfig.wbtc);
    }

    function run() public returns (STCEngine, StableCoin) {
        HelperConfig helperConfig = new HelperConfig();
        (address wethPriceFeed, address wbtcPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.localNetworkConfig();
        priceFeedAddresses = [wethPriceFeed , wbtcPriceFeed];
        tokenAddresses =[weth , wbtc];

        vm.startBroadcast(deployerKey);
        stableCoin = new StableCoin();
        stcEngine = new STCEngine(tokenAddresses, priceFeedAddresses, address(stableCoin));

        stableCoin.transferOwnership(address(stcEngine));
        vm.stopBroadcast();
        return (stcEngine, stableCoin);
    }
}
