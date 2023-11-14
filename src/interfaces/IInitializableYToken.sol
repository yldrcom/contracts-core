// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IYLDRIncentivesController} from "./IYLDRIncentivesController.sol";
import {IPool} from "./IPool.sol";

/**
 * @title IInitializableYToken
 *
 * @notice Interface for the initialize function on YToken
 */
interface IInitializableYToken {
    /**
     * @dev Emitted when an yToken is initialized
     * @param underlyingAsset The address of the underlying asset
     * @param pool The address of the associated pool
     * @param treasury The address of the treasury
     * @param incentivesController The address of the incentives controller for this yToken
     * @param yTokenDecimals The decimals of the underlying
     * @param yTokenName The name of the yToken
     * @param yTokenSymbol The symbol of the yToken
     * @param params A set of encoded parameters for additional initialization
     */
    event Initialized(
        address indexed underlyingAsset,
        address indexed pool,
        address treasury,
        address incentivesController,
        uint8 yTokenDecimals,
        string yTokenName,
        string yTokenSymbol,
        bytes params
    );

    /**
     * @notice Params for yToken initialization
     * @param pool The pool contract that is initializing this contract
     * @param treasury The address of the YLDR treasury, receiving the fees on this yToken
     * @param underlyingAsset The address of the underlying asset of this yToken (E.g. WETH for aWETH)
     * @param incentivesController The smart contract managing potential incentives distribution
     * @param yTokenDecimals The decimals of the yToken, same as the underlying asset's
     * @param yTokenName The name of the yToken
     * @param yTokenSymbol The symbol of the yToken
     * @param params A set of encoded parameters for additional initialization
     */
    struct InitializerParams {
        IPool initializingPool;
        address treasury;
        address underlyingAsset;
        IYLDRIncentivesController incentivesController;
        uint8 yTokenDecimals;
        string yTokenName;
        string yTokenSymbol;
        bytes params;
    }

    /**
      * @notice Initializes yToken
      * @param params The parameters to initialize in the format of InitializerParams defined above
     */
    function initialize(
        InitializerParams calldata params
    ) external;
}
