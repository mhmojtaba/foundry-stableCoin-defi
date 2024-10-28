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

    uint256 public timesMintIsCalled;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    address[] public usersWithCollateralDeposited;

    MockV3Aggregator public ethUsdPriceFeed;

    constructor(STCEngine _stcEngine, StableCoin _stc) {
        stableCoin = _stc;
        stcEngine = _stcEngine;

        address[] memory collateralTokens = stcEngine.getCollateralAddress();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(stcEngine.getCollateralTokenPriceFeed(address(weth)));
    }

    
    function minStc(uint256 amountSTC, uint256 addressSeed) public {
        if(usersWithCollateralDeposited.length == 0){
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 STCMinted, uint256 collateralValueInUsd) = stcEngine.getAccountInformation(sender);
        int256 maxAmountSTCToMint = (int256(collateralValueInUsd) /2) - int256(STCMinted);
        if (maxAmountSTCToMint < 0) {
            return;
        }
        amountSTC = bound(amountSTC, 0, uint256(maxAmountSTCToMint));
        if(amountSTC == 0) {
            return;
        }
        vm.startPrank(sender);
        stcEngine.mintSTC(amountSTC);
        vm.stopPrank();
        timesMintIsCalled++;
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
        usersWithCollateralDeposited.push(msg.sender);
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

    function updateCollateralPrice(uint96 newPrice) public {
        int256 _answer = int256(uint(newPrice));
        ethUsdPriceFeed.updateAnswer(_answer);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }
}
