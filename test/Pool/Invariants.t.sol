pragma solidity ^0.8.20;

import {BasePoolTest} from "./BasePoolTest.sol";
import {ERC1155Mock} from "../../src/mocks/ERC1155Mock.sol";
import {DataTypes} from "../../src/protocol/libraries/types/DataTypes.sol";
import {Errors} from "../../src/protocol/libraries/helpers/Errors.sol";
import {INToken} from "../../src/interfaces/INToken.sol";
import {IERC20Metadata as IERC20} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ReserveConfiguration} from "../../src/protocol/libraries/configuration/ReserveConfiguration.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract PoolHandler is CommonBase, StdUtils, StdCheats {
    using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

    PoolInvariants parent;

    bool expectFlash;

    constructor(PoolInvariants _parent) {
        parent = _parent;
    }

    function _getAssetByIndex(uint256 assetIndex) internal view returns (address) {
        address[] memory assets = parent.pool().getReservesList();
        return assets[_bound(assetIndex, 0, assets.length - 1)];
    }

    function supply(uint256 assetIndex, uint256 amount) public {
        amount = _bound(amount, 0, 1_000_000_000_000);
        vm.assume(amount > 0);

        address asset = _getAssetByIndex(assetIndex);
        deal(asset, msg.sender, amount);

        vm.startPrank(msg.sender);
        IERC20(asset).approve(address(parent.pool()), amount);
        parent.pool().supply(asset, amount, msg.sender, 0);
    }

    function withdraw(uint256 assetIndex, uint256 amount) public {
        address asset = _getAssetByIndex(assetIndex);
        DataTypes.ReserveData memory reserve = parent.pool().getReserveData(asset);

        (,,uint256 availableBorrowsBase,,,) = parent.pool().getUserAccountData(msg.sender);

        uint256 assetPrice = parent.oracle().getAssetPrice(asset);
        uint256 maxAmount =
            (availableBorrowsBase * 1e4 / reserve.configuration.getLtv()) * (10 ** IERC20(asset).decimals()) / assetPrice;
        maxAmount = Math.min(maxAmount, IERC20(reserve.yTokenAddress).balanceOf(msg.sender));
        maxAmount = Math.min(maxAmount, IERC20(asset).balanceOf(reserve.yTokenAddress));
        amount = _bound(amount, 0, maxAmount);

        vm.assume(amount > 0);

        vm.startPrank(msg.sender);
        parent.pool().withdraw(asset, amount, msg.sender);
    }

    function _getMaxBorrowAndAssume(address sender, address asset) internal view returns(uint256 maxBorrow) {
        DataTypes.ReserveData memory reserve = parent.pool().getReserveData(asset);
        uint256 assetPrice = parent.oracle().getAssetPrice(asset);

        (,,uint256 availableBorrowsBase,,,) = parent.pool().getUserAccountData(sender);

        maxBorrow = availableBorrowsBase * (10 ** IERC20(asset).decimals()) / assetPrice;
        maxBorrow = Math.min(maxBorrow, IERC20(asset).balanceOf(reserve.yTokenAddress));

        vm.assume(maxBorrow > 0);
    }

    function borrow(uint256 assetIndex, uint256 powerPercentToUse) public {
        powerPercentToUse = _bound(powerPercentToUse, 0, 10000);
        address asset = _getAssetByIndex(assetIndex);
        uint256 maxBorrow = _getMaxBorrowAndAssume(msg.sender, asset);

        uint256 amount = maxBorrow * powerPercentToUse / 10000;

        vm.assume(amount > 0);

        vm.startPrank(msg.sender);
        parent.pool().borrow(asset, amount, 0, msg.sender);
    }

    function repay(uint256 assetIndex, uint256 amount) public {
        address asset = _getAssetByIndex(assetIndex);
        DataTypes.ReserveData memory reserve = parent.pool().getReserveData(asset);
        amount = _bound(amount, 0, IERC20(reserve.variableDebtTokenAddress).balanceOf(msg.sender));

        vm.assume(amount > 0);

        deal(asset, msg.sender, amount);

        vm.startPrank(msg.sender);
        IERC20(asset).approve(address(parent.pool()), amount);
        parent.pool().repay(asset, amount, msg.sender);
    }

    function flash(uint256 assetIndex, uint256 amount, bool createPosition) public {
        address asset = _getAssetByIndex(assetIndex);
        DataTypes.ReserveData memory reserve = parent.pool().getReserveData(asset);
        uint256 maxAmount = createPosition ? _getMaxBorrowAndAssume(address(this), asset) : IERC20(asset).balanceOf(reserve.yTokenAddress);
        maxAmount = maxAmount / (1e4 + parent.pool().FLASHLOAN_PREMIUM_TOTAL()) * 1e4;
        amount = _bound(amount, 0, maxAmount);
        vm.assume(amount > 0);

        address[] memory assets = new address[](1);
        assets[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        bool[] memory createPositions = new bool[](1);
        createPositions[0] = createPosition;

        expectFlash = true;
        vm.stopPrank();
        parent.pool().flashLoan(address(this), assets, amounts, createPositions, address(this), new bytes(0), 0);
        expectFlash = false;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address,
        bytes calldata
    ) external returns (bool) {
        vm.assume(expectFlash);
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            uint256 amount = amounts[i];
            uint256 premium = premiums[i];

            IERC20(asset).approve(msg.sender, amount);
            parent.pool().supply(asset, amount, address(this), 0);

            deal(asset, address(this), amount + premium);
            IERC20(asset).approve(msg.sender, amount + premium);
        }

        return true;
    }

    function setFlashFees(uint256 totalFee, uint256 protocolFee) public {
        totalFee = _bound(totalFee, 0, 1e4);
        protocolFee = _bound(protocolFee, 0, 1e4);

        vm.startPrank(parent.ADMIN());
        parent.configurator().updateFlashloanPremiumTotal(uint128(totalFee));
        parent.configurator().updateFlashloanPremiumToProtocol(uint128(protocolFee));
    }

    function warp(uint256 sec) public {
        sec = _bound(sec, 0, 1e6);
        vm.warp(block.timestamp + sec);
    }
}

contract PoolInvariants is BasePoolTest {
    PoolHandler handler;

    function setUp() public {
        handler = new PoolHandler(this);

        targetContract(address(handler));

        targetSender(ADMIN);
        targetSender(ALICE);
        targetSender(BOB);
        targetSender(CAROL);

        vm.stopPrank();
    }

    function invariant_DebtPlusLiquidityIsTotalSupply() public {
        address[] memory reserves = pool.getReservesList();
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset = reserves[i];
            DataTypes.ReserveData memory reserve = pool.getReserveData(asset);
            uint256 totalDebt = IERC20(reserve.variableDebtTokenAddress).totalSupply();
            assertGe(
                IERC20(asset).balanceOf(reserve.yTokenAddress) + totalDebt, IERC20(reserve.yTokenAddress).totalSupply()
            );
        }
    }
}
