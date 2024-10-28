// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @title Oracle LIB
/// @author Mojtaba.web3
///  @notice This library is used to check the Chainlink Oracle for stale data. If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design. 
/// We want the DSCEngine to freeze if prices become stale.
/// So if the Chainlink network explodes and you have a lot of money locked in the protocol... too bad.

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant HEARTBEAT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface pricefeed) view public returns (uint80, int256, uint256, uint256, uint80) {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) = pricefeed.latestRoundData();
        uint256 secondsSinces = block.timestamp - updatedAt;

        if(secondsSinces > HEARTBEAT) revert OracleLib__StalePrice();

        return ( roundId,  answer,  startedAt,  updatedAt,  answeredInRound);
    }

}