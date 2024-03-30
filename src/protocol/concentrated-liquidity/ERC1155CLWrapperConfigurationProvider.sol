// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC1155ConfigurationProvider} from "../../interfaces/IERC1155ConfigurationProvider.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {ReserveConfiguration} from "../libraries/configuration/ReserveConfiguration.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseERC1155CLWrapper} from "./erc1155-wrappers/BaseERC1155CLWrapper.sol";

contract ERC1155CLWrapperConfigurationProvider is IERC1155ConfigurationProvider {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    IPool public immutable pool;
    BaseERC1155CLWrapper public immutable wrapper;

    constructor(IPool _pool, BaseERC1155CLWrapper _wrapper) {
        pool = _pool;
        wrapper = _wrapper;
    }

    function getERC1155ReserveConfig(uint256 tokenId)
        external
        view
        returns (DataTypes.ERC1155ReserveConfiguration memory)
    {
        BaseERC1155CLWrapper.PositionData memory position = wrapper.getPositionData(tokenId);

        DataTypes.ReserveConfigurationMap memory config0 = pool.getConfiguration(position.token0);
        DataTypes.ReserveConfigurationMap memory config1 = pool.getConfiguration(position.token1);

        (bool isActive0, bool isFrozen0,, bool isPaused0) = config0.getFlags();
        (bool isActive1, bool isFrozen1,, bool isPaused1) = config1.getFlags();

        uint256 liquidationThreshold = Math.min(config0.getLiquidationThreshold(), config1.getLiquidationThreshold());
        uint256 liquidationBonus = Math.max(config0.getLiquidationBonus(), config1.getLiquidationBonus());
        uint256 ltv = Math.min(config0.getLtv(), config1.getLtv());

        return DataTypes.ERC1155ReserveConfiguration({
            isActive: isActive0 && isActive1,
            isFrozen: isFrozen0 || isFrozen1,
            isPaused: isPaused0 || isPaused1,
            ltv: ltv,
            liquidationThreshold: liquidationThreshold,
            liquidationBonus: liquidationBonus
        });
    }
}
