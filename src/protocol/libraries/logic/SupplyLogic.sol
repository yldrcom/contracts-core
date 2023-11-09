// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC20} from "../../../dependencies/openzeppelin/contracts/IERC20.sol";
import {IERC1155} from "../../../dependencies/openzeppelin/contracts/IERC1155.sol";
import {GPv2SafeERC20} from "../../../dependencies/gnosis/contracts/GPv2SafeERC20.sol";
import {IYToken} from "../../../interfaces/IYToken.sol";
import {INToken} from "../../../interfaces/INToken.sol";
import {Errors} from "../helpers/Errors.sol";
import {UserConfiguration} from "../configuration/UserConfiguration.sol";
import {UserERC1155Configuration} from "../configuration/UserERC1155Configuration.sol";
import {DataTypes} from "../types/DataTypes.sol";
import {WadRayMath} from "../math/WadRayMath.sol";
import {PercentageMath} from "../math/PercentageMath.sol";
import {ValidationLogic} from "./ValidationLogic.sol";
import {ReserveLogic} from "./ReserveLogic.sol";
import {ReserveConfiguration} from "../configuration/ReserveConfiguration.sol";
import {ERC1155ReserveLogic} from "./ERC1155ReserveLogic.sol";

/**
 * @title SupplyLogic library
 *
 * @notice Implements the base logic for supply/withdraw
 */
library SupplyLogic {
    using ReserveLogic for DataTypes.ReserveCache;
    using ReserveLogic for DataTypes.ReserveData;
    using ERC1155ReserveLogic for DataTypes.ERC1155ReserveCache;
    using ERC1155ReserveLogic for DataTypes.ERC1155ReserveData;
    using GPv2SafeERC20 for IERC20;
    using UserConfiguration for DataTypes.UserConfigurationMap;
    using UserERC1155Configuration for DataTypes.UserERC1155ConfigurationMap;
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
    using WadRayMath for uint256;
    using PercentageMath for uint256;

    // See `IPool` for descriptions
    event ReserveUsedAsCollateralEnabled(address indexed reserve, address indexed user);
    event ReserveUsedAsCollateralDisabled(address indexed reserve, address indexed user);
    event ERC1155ReserveUsedAsCollateralEnabled(address indexed reserve, uint256 indexed tokenId, address indexed user);
    event ERC1155ReserveUsedAsCollateralDisabled(
        address indexed reserve, uint256 indexed tokenId, address indexed user
    );
    event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);
    event WithdrawERC1155(address indexed reserve, address user, address indexed to, uint256 tokenId, uint256 amount);
    event Supply(
        address indexed reserve, address user, address indexed onBehalfOf, uint256 amount, uint16 indexed referralCode
    );
    event SupplyERC1155(
        address indexed reserve,
        address user,
        address indexed onBehalfOf,
        uint256 tokenId,
        uint256 amount,
        uint16 indexed referralCode
    );

    /**
     * @notice Implements the supply feature. Through `supply()`, users supply assets to the YLDR protocol.
     * @dev Emits the `Supply()` event.
     * @dev In the first supply action, `ReserveUsedAsCollateralEnabled()` is emitted, if the asset can be enabled as
     * collateral.
     * @param reservesData The state of all the reserves
     * @param userConfig The user configuration mapping that tracks the supplied/borrowed assets
     * @param params The additional parameters needed to execute the supply function
     */
    function executeSupply(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.ExecuteSupplyParams memory params
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        DataTypes.ReserveCache memory reserveCache = reserve.cache();

        reserve.updateState(reserveCache);

        ValidationLogic.validateSupply(reserveCache, reserve, params.amount);

        reserve.updateInterestRates(reserveCache, params.asset, params.amount, 0);

        IERC20(params.asset).safeTransferFrom(msg.sender, reserveCache.yTokenAddress, params.amount);

        bool isFirstSupply = IYToken(reserveCache.yTokenAddress).mint(
            msg.sender, params.onBehalfOf, params.amount, reserveCache.nextLiquidityIndex
        );

        if (isFirstSupply) {
            if (ValidationLogic.validateUseAsCollateral(reserveCache.reserveConfiguration)) {
                userConfig.setUsingAsCollateral(reserve.id, true);
                emit ReserveUsedAsCollateralEnabled(params.asset, params.onBehalfOf);
            }
        }

        emit Supply(params.asset, msg.sender, params.onBehalfOf, params.amount, params.referralCode);
    }

    /**
     * @notice Implements the supply ERC1155 feature. Through `supplyERC1155()`, users supply assets to the YLDR protocol.
     * @dev Emits the `SupplyERC1155()` event.
     * @dev In the first supply action, `ERC1155ReserveUsedAsCollateralEnabled()` is emitted, if the asset can be enabled as
     * collateral.
     * @param erc1155ReservesData The state of all the reserves
     * @param userERC1155Config The user configuration mapping that tracks the supplied/borrowed ERC1155 assets
     * @param params The additional parameters needed to execute the supply function
     */
    function executeSupplyERC1155(
        mapping(address => DataTypes.ERC1155ReserveData) storage erc1155ReservesData,
        DataTypes.UserERC1155ConfigurationMap storage userERC1155Config,
        DataTypes.ExecuteSupplyERC1155Params memory params
    ) external {
        DataTypes.ERC1155ReserveData storage reserve = erc1155ReservesData[params.asset];
        DataTypes.ERC1155ReserveCache memory reserveCache = reserve.cache();

        ValidationLogic.validateSupplyERC1155(reserveCache, params.amount);

        IERC1155(params.asset).safeTransferFrom(
            msg.sender, reserveCache.nTokenAddress, params.tokenId, params.amount, bytes("")
        );

        bool isFirstSupply =
            INToken(reserveCache.nTokenAddress).mint(msg.sender, params.onBehalfOf, params.tokenId, params.amount);

        if (isFirstSupply) {
            if (ValidationLogic.validateUseERC1155AsCollateral(reserveCache)) {
                userERC1155Config.setUsingAsCollateral(reserve.id, params.tokenId, true);
                emit ERC1155ReserveUsedAsCollateralEnabled(params.asset, params.tokenId, params.onBehalfOf);
            }
        }

        emit SupplyERC1155(
            params.asset, msg.sender, params.onBehalfOf, params.tokenId, params.amount, params.referralCode
        );
    }

    struct ExecuteWithdrawLocalVars {
        DataTypes.ReserveCache reserveCache;
        uint256 userBalance;
        uint256 amountToWithdraw;
    }

    /**
     * @notice Implements the withdraw feature. Through `withdraw()`, users redeem their yTokens for the underlying asset
     * previously supplied in the YLDR protocol.
     * @dev Emits the `Withdraw()` event.
     * @dev If the user withdraws everything, `ReserveUsedAsCollateralDisabled()` is emitted.
     * @param reservesData The state of all the reserves
     * @param reservesList The addresses of all the active reserves
     * @param userConfig The user configuration mapping that tracks the supplied/borrowed assets
     * @param params The additional parameters needed to execute the withdraw function
     * @return The actual amount withdrawn
     */
    function executeWithdraw(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(address => DataTypes.ERC1155ReserveData) storage erc1155ReservesData,
        mapping(uint256 => address) storage erc1155ReservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.UserERC1155ConfigurationMap storage userERC1155Config,
        DataTypes.ExecuteWithdrawParams memory params
    ) external returns (uint256) {
        ExecuteWithdrawLocalVars memory vars;

        DataTypes.ReserveData storage reserve = reservesData[params.asset];
        vars.reserveCache = reserve.cache();

        reserve.updateState(vars.reserveCache);

        vars.userBalance = IYToken(vars.reserveCache.yTokenAddress).scaledBalanceOf(msg.sender).rayMul(
            vars.reserveCache.nextLiquidityIndex
        );

        vars.amountToWithdraw = params.amount;

        if (params.amount == type(uint256).max) {
            vars.amountToWithdraw = vars.userBalance;
        }

        ValidationLogic.validateWithdraw(vars.reserveCache, vars.amountToWithdraw, vars.userBalance);

        reserve.updateInterestRates(vars.reserveCache, params.asset, 0, vars.amountToWithdraw);

        bool isCollateral = userConfig.isUsingAsCollateral(reserve.id);

        if (isCollateral && vars.amountToWithdraw == vars.userBalance) {
            userConfig.setUsingAsCollateral(reserve.id, false);
            emit ReserveUsedAsCollateralDisabled(params.asset, msg.sender);
        }

        IYToken(vars.reserveCache.yTokenAddress).burn(
            msg.sender, params.to, vars.amountToWithdraw, vars.reserveCache.nextLiquidityIndex
        );

        if (isCollateral && userConfig.isBorrowingAny()) {
            ValidationLogic.validateHFAndLtv(
                reservesData,
                reservesList,
                erc1155ReservesData,
                erc1155ReservesList,
                userConfig,
                userERC1155Config,
                params.asset,
                msg.sender,
                params.reservesCount,
                params.oracle
            );
        }

        emit Withdraw(params.asset, msg.sender, params.to, vars.amountToWithdraw);

        return vars.amountToWithdraw;
    }

    struct ExecuteWithdrawERC1155LocalVars {
        DataTypes.ERC1155ReserveCache reserveCache;
        uint256 userBalance;
        uint256 amountToWithdraw;
    }

    /**
     * @notice Implements the withdraw feature. Through `withdraw()`, users redeem their yTokens for the underlying asset
     * previously supplied in the YLDR protocol.
     * @dev Emits the `Withdraw()` event.
     * @dev If the user withdraws everything, `ReserveUsedAsCollateralDisabled()` is emitted.
     * @param reservesData The state of all the reserves
     * @param reservesList The addresses of all the active reserves
     * @param userConfig The user configuration mapping that tracks the supplied/borrowed assets
     * @param params The additional parameters needed to execute the withdraw function
     * @return The actual amount withdrawn
     */
    function executeWithdrawERC1155(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(address => DataTypes.ERC1155ReserveData) storage erc1155ReservesData,
        mapping(uint256 => address) storage erc1155ReservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.UserERC1155ConfigurationMap storage userERC1155Config,
        DataTypes.ExecuteWithdrawERC1155Params memory params
    ) external returns (uint256) {
        ExecuteWithdrawERC1155LocalVars memory vars;

        DataTypes.ERC1155ReserveData storage reserve = erc1155ReservesData[params.asset];
        vars.reserveCache = reserve.cache();

        vars.userBalance = INToken(vars.reserveCache.nTokenAddress).balanceOf(msg.sender, params.tokenId);

        vars.amountToWithdraw = params.amount;

        if (params.amount == type(uint256).max) {
            vars.amountToWithdraw = vars.userBalance;
        }

        ValidationLogic.validateWithdrawERC1155(vars.reserveCache, vars.amountToWithdraw, vars.userBalance);

        bool isCollateral = userERC1155Config.isUsingAsCollateral(reserve.id, params.tokenId);

        if (isCollateral && vars.amountToWithdraw == vars.userBalance) {
            userERC1155Config.setUsingAsCollateral(reserve.id, params.tokenId, false);
            emit ERC1155ReserveUsedAsCollateralDisabled(params.asset, params.tokenId, msg.sender);
        }

        INToken(vars.reserveCache.nTokenAddress).burn(msg.sender, params.to, params.tokenId, vars.amountToWithdraw);

        if (isCollateral && userConfig.isBorrowingAny()) {
            ValidationLogic.validateHFAndLtv(
                reservesData,
                reservesList,
                erc1155ReservesData,
                erc1155ReservesList,
                userConfig,
                userERC1155Config,
                params.asset,
                msg.sender,
                params.reservesCount,
                params.oracle
            );
        }

        emit WithdrawERC1155(params.asset, msg.sender, params.to, params.tokenId, vars.amountToWithdraw);

        return vars.amountToWithdraw;
    }

    /**
     * @notice Validates a transfer of yTokens. The sender is subjected to health factor validation to avoid
     * collateralization constraints violation.
     * @dev Emits the `ReserveUsedAsCollateralEnabled()` event for the `to` account, if the asset is being activated as
     * collateral.
     * @dev In case the `from` user transfers everything, `ReserveUsedAsCollateralDisabled()` is emitted for `from`.
     * @param reservesData The state of all the reserves
     * @param reservesList The addresses of all the active reserves
     * @param usersConfig The users configuration mapping that track the supplied/borrowed assets
     * @param params The additional parameters needed to execute the finalizeTransfer function
     */
    function executeFinalizeTransfer(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(address => DataTypes.ERC1155ReserveData) storage erc1155ReservesData,
        mapping(uint256 => address) storage erc1155ReservesList,
        mapping(address => DataTypes.UserConfigurationMap) storage usersConfig,
        mapping(address => DataTypes.UserERC1155ConfigurationMap) storage usersERC1155Config,
        DataTypes.FinalizeTransferParams memory params
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[params.asset];

        ValidationLogic.validateTransfer(reserve);

        uint256 reserveId = reserve.id;

        if (params.from != params.to && params.amount != 0) {
            DataTypes.UserConfigurationMap storage fromConfig = usersConfig[params.from];

            if (fromConfig.isUsingAsCollateral(reserveId)) {
                if (fromConfig.isBorrowingAny()) {
                    ValidationLogic.validateHFAndLtv(
                        reservesData,
                        reservesList,
                        erc1155ReservesData,
                        erc1155ReservesList,
                        usersConfig[params.from],
                        usersERC1155Config[params.from],
                        params.asset,
                        params.from,
                        params.reservesCount,
                        params.oracle
                    );
                }
                if (params.balanceFromBefore == params.amount) {
                    fromConfig.setUsingAsCollateral(reserveId, false);
                    emit ReserveUsedAsCollateralDisabled(params.asset, params.from);
                }
            }

            if (params.balanceToBefore == 0) {
                DataTypes.UserConfigurationMap storage toConfig = usersConfig[params.to];
                if (ValidationLogic.validateUseAsCollateral(reserve.configuration)) {
                    toConfig.setUsingAsCollateral(reserveId, true);
                    emit ReserveUsedAsCollateralEnabled(params.asset, params.to);
                }
            }
        }
    }

    /**
     * @notice Executes the 'set as collateral' feature. A user can choose to activate or deactivate an asset as
     * collateral at any point in time. Deactivating an asset as collateral is subjected to the usual health factor
     * checks to ensure collateralization.
     * @dev Emits the `ReserveUsedAsCollateralEnabled()` event if the asset can be activated as collateral.
     * @dev In case the asset is being deactivated as collateral, `ReserveUsedAsCollateralDisabled()` is emitted.
     * @param reservesData The state of all the reserves
     * @param reservesList The addresses of all the active reserves
     * @param userConfig The users configuration mapping that track the supplied/borrowed assets
     * @param asset The address of the asset being configured as collateral
     * @param useAsCollateral True if the user wants to set the asset as collateral, false otherwise
     * @param reservesCount The number of initialized reserves
     * @param priceOracle The address of the price oracle
     */
    function executeUseReserveAsCollateral(
        mapping(address => DataTypes.ReserveData) storage reservesData,
        mapping(uint256 => address) storage reservesList,
        mapping(address => DataTypes.ERC1155ReserveData) storage erc1155ReservesData,
        mapping(uint256 => address) storage erc1155ReservesList,
        DataTypes.UserConfigurationMap storage userConfig,
        DataTypes.UserERC1155ConfigurationMap storage userERC1155Config,
        address asset,
        bool useAsCollateral,
        uint256 reservesCount,
        address priceOracle
    ) external {
        DataTypes.ReserveData storage reserve = reservesData[asset];
        DataTypes.ReserveCache memory reserveCache = reserve.cache();

        uint256 userBalance = IERC20(reserveCache.yTokenAddress).balanceOf(msg.sender);

        ValidationLogic.validateSetUseReserveAsCollateral(reserveCache, userBalance);

        if (useAsCollateral == userConfig.isUsingAsCollateral(reserve.id)) return;

        if (useAsCollateral) {
            require(ValidationLogic.validateUseAsCollateral(reserveCache.reserveConfiguration), Errors.LTV_ZERO);

            userConfig.setUsingAsCollateral(reserve.id, true);
            emit ReserveUsedAsCollateralEnabled(asset, msg.sender);
        } else {
            userConfig.setUsingAsCollateral(reserve.id, false);
            ValidationLogic.validateHFAndLtv(
                reservesData,
                reservesList,
                erc1155ReservesData,
                erc1155ReservesList,
                userConfig,
                userERC1155Config,
                asset,
                msg.sender,
                reservesCount,
                priceOracle
            );

            emit ReserveUsedAsCollateralDisabled(asset, msg.sender);
        }
    }
}
