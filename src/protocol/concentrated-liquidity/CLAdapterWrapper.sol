// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {BaseCLAdapter} from "./adapters/BaseCLAdapter.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @notice A library to delegate calls to a BaseCLAdapter contract
library CLAdapterWrapper {
    using Address for address;

    function delegateIncreaseLiquidity(BaseCLAdapter adapter, uint256 tokenId, uint256 amount0, uint256 amount1)
        internal
        returns (uint256 amount0Resulted, uint256 amount1Resulted)
    {
        bytes memory result = address(adapter).functionDelegateCall(
            abi.encodeCall(adapter.increaseLiquidity, (tokenId, amount0, amount1))
        );
        return abi.decode(result, (uint256, uint256));
    }

    function delegateDecreaseLiquidity(BaseCLAdapter adapter, uint256 tokenId, uint128 liquidity)
        internal
        returns (uint256 amount0Resulted, uint256 amount1Resulted)
    {
        bytes memory result =
            address(adapter).functionDelegateCall(abi.encodeCall(adapter.decreaseLiquidity, (tokenId, liquidity)));
        return abi.decode(result, (uint256, uint256));
    }

    function delegateCollectFees(
        BaseCLAdapter adapter,
        uint256 tokenId,
        uint128 amount0Max,
        uint128 amount1Max,
        address recipient
    ) internal returns (uint256 amount0Resulted, uint256 amount1Resulted) {
        bytes memory result = address(adapter).functionDelegateCall(
            abi.encodeCall(adapter.collectFees, (tokenId, amount0Max, amount1Max, recipient))
        );
        return abi.decode(result, (uint256, uint256));
    }

    function delegateMintPosition(BaseCLAdapter adapter, BaseCLAdapter.MintParams memory params)
        internal
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        bytes memory result = address(adapter).functionDelegateCall(abi.encodeCall(adapter.mintPosition, (params)));
        return abi.decode(result, (uint256, uint128, uint256, uint256));
    }
}
