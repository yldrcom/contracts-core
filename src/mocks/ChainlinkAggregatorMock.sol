pragma solidity ^0.8.20;

import {IChainlinkAggregator} from "../interfaces/ext/IChainlinkAggregator.sol";

contract ChainlinkAggregatorMock is IChainlinkAggregator {
    int256 public latestAnswer;

    constructor(int256 answer) {
        latestAnswer = answer;
    }

    function setAnswer(int256 answer) external {
        latestAnswer = answer;
    }

    function latestTimestamp() external pure returns (uint256) {
        revert("not implemented");
    }

    function latestRound() external pure returns (uint256) {
        revert("not implemented");
    }

    function getAnswer(uint256) external pure returns (int256) {
        revert("not implemented");
    }

    function getTimestamp(uint256) external pure returns (uint256) {
        revert("not implemented");
    }
}
