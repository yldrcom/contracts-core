// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {BaseERC1155CLWrapper} from "./BaseERC1155CLWrapper.sol";
import {AlgebraV1Adapter} from "../adapters/AlgebraV1Adapter.sol";

contract ERC1155AlgebraV1Wrapper is BaseERC1155CLWrapper, AlgebraV1Adapter {
    constructor(address _positionManager) AlgebraV1Adapter(_positionManager) {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("");
    }
}
