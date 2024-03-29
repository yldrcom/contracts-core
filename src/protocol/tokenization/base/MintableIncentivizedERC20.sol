// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IYLDRIncentivesController} from "../../../interfaces/IYLDRIncentivesController.sol";
import {IPool} from "../../../interfaces/IPool.sol";
import {IncentivizedERC20} from "./IncentivizedERC20.sol";

/**
 * @title MintableIncentivizedERC20
 *
 * @notice Implements mint and burn functions for IncentivizedERC20
 */
abstract contract MintableIncentivizedERC20 is IncentivizedERC20 {
    /**
     * @dev Constructor.
     * @param pool The reference to the main Pool contract
     * @param name_ The name of the token
     * @param symbol_ The symbol of the token
     * @param decimals_ The number of decimals of the token
     */
    constructor(IPool pool, string memory name_, string memory symbol_, uint8 decimals_)
        IncentivizedERC20(pool, name_, symbol_, decimals_)
    {
        // Intentionally left blank
    }

    /**
     * @notice Mints tokens to an account and apply incentives if defined
     * @param account The address receiving tokens
     * @param amount The amount of tokens to mint
     */
    function _mint(address account, uint128 amount) internal virtual {
        uint256 oldTotalSupply = _totalSupply;
        _totalSupply = oldTotalSupply + amount;

        uint128 oldAccountBalance = _userState[account].balance;
        _userState[account].balance = oldAccountBalance + amount;

        IYLDRIncentivesController incentivesControllerLocal = _incentivesController;
        if (address(incentivesControllerLocal) != address(0)) {
            incentivesControllerLocal.handleAction(account, oldTotalSupply, oldAccountBalance);
        }
    }

    /**
     * @notice Burns tokens from an account and apply incentives if defined
     * @param account The account whose tokens are burnt
     * @param amount The amount of tokens to burn
     */
    function _burn(address account, uint128 amount) internal virtual {
        uint256 oldTotalSupply = _totalSupply;
        _totalSupply = oldTotalSupply - amount;

        uint128 oldAccountBalance = _userState[account].balance;
        _userState[account].balance = oldAccountBalance - amount;

        IYLDRIncentivesController incentivesControllerLocal = _incentivesController;

        if (address(incentivesControllerLocal) != address(0)) {
            incentivesControllerLocal.handleAction(account, oldTotalSupply, oldAccountBalance);
        }
    }
}
