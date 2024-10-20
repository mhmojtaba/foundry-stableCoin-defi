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

    function run() public returns (STCEngine, StableCoin) {
        HelperConfig helperConfig = new HelperConfig();
        (address wethPriceFeed, address wbtcPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.localNetworkConfig();
        // tokenAddresses.push(weth);
        // tokenAddresses.push(wbtc);
        // priceFeedAddresses.push(wethPriceFeed);
        // priceFeedAddresses.push(wbtcPriceFeed);
        console.log("WETH address:", weth);
        console.log("WETH price feed address:", wethPriceFeed);
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
