// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAINID = 31337;
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD = 2600e8;
    int256 public constant BTC_USD = 68000e8;

    struct NetworkConfig {
        address wethPriceFeed;
        address wbtcPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    NetworkConfig public localNetworkConfig;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            localNetworkConfig = getSepoliaConfig();
        } else {
            localNetworkConfig = getorCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig(
            0x694AA1769357215DE4FAC081bf1f309aDC325306, // weth address
            0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, //wbtcPriceFeed
            0xdd13E55209Fd76AfE204dBda4007C227904f0a81, //weth
            0x92f3B59a79bFf5dc60c0d59eA13a44D082B2bdFC, //wbtc
            vm.envUint("PRIVATE_KEY") //deployerKey
        );
    }

    // function getConfig() public returns (NetworkConfig memory) {
    //     return getConfigByChainID(block.chainid);
    // }

    function getorCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.wethPriceFeed != address(0)) {
            return localNetworkConfig;
        }

        // deploy MockV3Aggregator
        vm.startBroadcast();
        MockV3Aggregator wethUsdPrice = new MockV3Aggregator(DECIMALS, ETH_USD);
        MockV3Aggregator wbtcUsdPrice = new MockV3Aggregator(DECIMALS, BTC_USD);
        ERC20Mock wethAddress = new ERC20Mock("WETH", "weth"); // ERC20mock contract using openzeppelin
        ERC20Mock wbtcAddress = new ERC20Mock("WBTC", "wbtc"); // ERC20mock contract using openzeppelin

        // MockERC20 wethAddress = new MockERC20().initialize("WETH","weth",18); // ERC20mock contract using forge-std
        // MockERC20 wbtcAddress = new MockERC20().initialize("WBTC","wbtc", 8); // ERC20mock contract using forge-std
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig(
            address(wethUsdPrice), // weth address
            address(wbtcUsdPrice), //wbtcPriceFeed
            address(wethAddress), //weth
            address(wbtcAddress), //wbtc
            vm.envUint("DEFAULT_ANVIL_KEY") //deployerKey
        );
        return localNetworkConfig;
    }
}
