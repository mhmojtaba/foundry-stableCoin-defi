// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {STCEngine} from "src/STCEngine.sol";
import {StableCoin} from "src/StableCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployStcEngine} from "script/DeployStcEngine.s.sol";
import {Vm} from "forge-std/Vm.sol";


contract CounterTest is Test {
    HelperConfig public helperConfig;
    STCEngine stcEngine;
    StableCoin stableCoin;
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    // make user
    address public player = makeAddr("user");

    function setUp() public {
        DeployStcEngine deployer = new DeployStcEngine();
        stcEngine = deployer.run();
    }
}
