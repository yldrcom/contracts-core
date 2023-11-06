// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {YToken} from "../../protocol/tokenization/YToken.sol";
import {IPool} from "../../interfaces/IPool.sol";

contract MockYToken is YToken {
    constructor(IPool pool) YToken(pool) {}

    function getRevision() internal pure override returns (uint256) {
        return 0x2;
    }
}
