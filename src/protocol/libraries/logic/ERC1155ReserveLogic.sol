// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20} from "../../../dependencies/openzeppelin/contracts/IERC20.sol";
import {GPv2SafeERC20} from "../../../dependencies/gnosis/contracts/GPv2SafeERC20.sol";
import {IStableDebtToken} from "../../../interfaces/IStableDebtToken.sol";
import {IVariableDebtToken} from "../../../interfaces/IVariableDebtToken.sol";
import {IReserveInterestRateStrategy} from "../../../interfaces/IReserveInterestRateStrategy.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {MathUtils} from "../math/MathUtils.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {Errors} from "../helpers/Errors.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {SafeCast} from "../../../dependencies/openzeppelin/contracts/SafeCast.sol";

/**
 * @title ERC1155ReserveLogic library
 *
 * @notice Implements the logic to update ERC1155 reserves state
 */
library ERC1155ReserveLogic {
    using ERC1155ReserveLogic for DataTypes.ERC1155ReserveData;

    /**
     * @notice Creates a cache object to avoid repeated storage reads and external contract calls when updating state and
     * interest rates.
     * @param erc1155Reserve The reserve object for which the cache will be filled
     * @return The cache object
     */
    function cache(DataTypes.ERC1155ReserveData storage erc1155Reserve)
        internal
        view
        returns (DataTypes.ERC1155ReserveCache memory)
    {
        return DataTypes.ERC1155ReserveCache({
            id: erc1155Reserve.id,
            isActive: erc1155Reserve.isActive,
            isPaused: erc1155Reserve.isPaused,
            isFrozen: erc1155Reserve.isFrozen,
            nTokenAddress: erc1155Reserve.nTokenAddress,
            ltv: erc1155Reserve.ltv
        });
    }
}
