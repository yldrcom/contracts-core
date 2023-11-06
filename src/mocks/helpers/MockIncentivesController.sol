// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IYLDRIncentivesController} from "../../interfaces/IYLDRIncentivesController.sol";

contract MockIncentivesController is IYLDRIncentivesController {
    function handleAction(address, uint256, uint256) external override {}
}
