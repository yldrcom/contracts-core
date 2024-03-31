// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {BaseERC1155CLWrapper} from "./BaseERC1155CLWrapper.sol";
import {UniswapV3Adapter} from "../adapters/UniswapV3Adapter.sol";

contract ERC1155UniswapV3Wrapper is BaseERC1155CLWrapper, UniswapV3Adapter {
    constructor(address _positionManager) UniswapV3Adapter(_positionManager) {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC1155_init("");
    }
}
