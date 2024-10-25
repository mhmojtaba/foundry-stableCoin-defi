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
    STCEngine stcEngine;
    StableCoin stableCoin;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(STCEngine _stcEngine, StableCoin _stc) {
        stableCoin = _stc;
        stcEngine = _stcEngine;

        address[] memory collateralTokens = stcEngine.getCollateralAddress();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

    }

    function depositeCollateral(
        uint256 collateralSeed, // random vslid collateral
        uint256 collateralAmount // random amount of collateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        collateralAmount = bound(collateralAmount, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, collateralAmount);
        collateral.approve(address(stcEngine), collateralAmount);
        stcEngine.depositeCollateral(address(collateral), collateralAmount);
        vm.stopPrank();
    }

    function minStc(uint256 amountSTC) public {
        (uint256 STCMinted, uint256 collateralValueInUsd) = stcEngine.getAccountInformation(msg.sender);
        int256 maxAmountSTCToMint = (int256(collateralValueInUsd) /2) - int256(STCMinted);
        if (maxAmountSTCToMint < 0) {
            return;
        }
        amountSTC = bound(amountSTC, 0, uint256(maxAmountSTCToMint));
        if(amountSTC == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        stcEngine.mintSTC(amountSTC);
        vm.stopPrank();
    }


    function redeemCollateral(
        uint256 collateralSeed, // random vslid collateral
        uint256 collateralAmount // random amount of collateral
    ) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        uint256 maxCollateralToRedeem = stcEngine.getCollateralBalanceOfUser(msg.sender , address(collateral));

        collateralAmount = bound(collateralAmount, 0, maxCollateralToRedeem);
        if(collateralAmount == 0) {
            return;
        }
        // vm.assume(collateralAmount == 0);
        stcEngine.redeemCollateral(address(collateral),collateralAmount);

    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
