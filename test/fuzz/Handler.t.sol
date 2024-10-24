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

contract Handler is Test {
    HelperConfig public helperConfig;
}
