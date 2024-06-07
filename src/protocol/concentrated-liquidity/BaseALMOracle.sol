// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IChainlinkAggregator} from "../../interfaces/ext/IChainlinkAggregator.sol";
import {BaseCLAdapter} from "../../protocol/concentrated-liquidity/adapters/BaseCLAdapter.sol";

interface BaseALMOracle is IChainlinkAggregator {
    /// @notice Underlying CL pool
    function pool() external view returns(address);

    /// @notice CL adapter for underlying pool CL protocol
    function adapter() external view returns(BaseCLAdapter);
}
