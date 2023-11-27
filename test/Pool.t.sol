pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {IYLDROracle} from "src/interfaces/IYLDROracle.sol";
import {ERC20Mock} from "src/mocks/ERC20Mock.sol";
import {ERC1155Mock} from "src/mocks/ERC1155Mock.sol";
import {ERC1155ConfigurationProviderMock} from "src/mocks/ERC1155ConfigurationProviderMock.sol";
import {ERC1155PriceOracleMock} from "src/mocks/ERC1155PriceOracleMock.sol";
import {Errors} from "src/protocol/libraries/helpers/Errors.sol";
import {DataTypes} from "src/protocol/libraries/types/DataTypes.sol";
import {BaseTest} from "test/base/BaseTest.sol";
import {PoolTesting} from "test/libraries/PoolTesting.sol";
import {ChainlinkAggregatorMock} from "src/mocks/ChainlinkAggregatorMock.sol";

contract PoolTest is BaseTest {
    using PoolTesting for PoolTesting.Data;

    IPool pool;
    IYLDROracle oracle;

    ERC20Mock usdc;
    ERC20Mock weth;
    ERC1155Mock nfts;

    PoolTesting.Data poolTesting;

    ERC1155ConfigurationProviderMock configurationProvider;
    ERC1155PriceOracleMock erc1155Oracle;

    constructor() {
        vm.startPrank(ADMIN);

        usdc = new ERC20Mock("USD Coin", "USDC", 6);
        weth = new ERC20Mock("Wrapped Ether", "WETH", 18);
        nfts = new ERC1155Mock();

        _addAndDealToken(usdc);
        _addAndDealToken(weth);

        poolTesting.init(ADMIN);

        pool = IPool(poolTesting.addressesProvider.getPool());
        oracle = IYLDROracle(poolTesting.addressesProvider.getPriceOracle());

        poolTesting.addReserve(
            address(usdc), 0.8e27, 0, 0.02e27, 0.8e27, 0.7e4, 0.75e4, 1.05e4, address(new ChainlinkAggregatorMock(1e8))
        );
        poolTesting.addReserve(
            address(weth),
            0.8e27,
            0,
            0.02e27,
            0.8e27,
            0.7e4,
            0.75e4,
            1.05e4,
            address(new ChainlinkAggregatorMock(1000e8))
        );

        configurationProvider = new ERC1155ConfigurationProviderMock();
        erc1155Oracle = new ERC1155PriceOracleMock();

        poolTesting.addERC1155Reserve(address(nfts), address(configurationProvider), address(erc1155Oracle));
        vm.stopPrank();

        _approveAllTokensForAllCallers(address(pool));

        vm.startPrank(ALICE);
        nfts.setApprovalForAll(address(pool), true);

        vm.startPrank(BOB);
        nfts.setApprovalForAll(address(pool), true);

        vm.startPrank(CAROL);
        nfts.setApprovalForAll(address(pool), true);
    }

    function _test_supply_borrow_repay_withdraw(bool direction) internal {
        (address collateral, address debt) = direction ? (address(usdc), address(weth)) : (address(weth), address(usdc));
        vm.startPrank(ALICE);
        pool.supply(address(usdc), 10_000e6, ALICE, 0);

        vm.startPrank(BOB);
        pool.supply(address(weth), 10e18, BOB, 0);
        pool.borrow(address(usdc), 1_000e6, 0, BOB);
        pool.repay(address(usdc), 1_000e6, BOB);
        pool.withdraw(address(weth), 10e18, BOB);
    }

    function test_supply_borrow_repay_withdraw() public {
        _test_supply_borrow_repay_withdraw(true);
        _test_supply_borrow_repay_withdraw(false);
    }

    function test_supply_borrow_liquidate() public {
        vm.startPrank(ALICE);
        pool.supply(address(usdc), 10_000e6, ALICE, 0);

        vm.startPrank(BOB);
        pool.supply(address(weth), 10e18, BOB, 0);
        pool.borrow(address(usdc), 1_000e6, 0, BOB);

        vm.expectRevert(bytes(Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW));
        pool.borrow(address(usdc), 8_000e6, 0, BOB);

        vm.startPrank(ADMIN);
        ChainlinkAggregatorMock(oracle.getSourceOfAsset(address(weth))).setAnswer(100e8);

        vm.startPrank(CAROL);
        pool.liquidationCall(address(weth), address(usdc), BOB, 8_000e6, false);
        vm.stopPrank();
    }

    function test_ERC1155() public {
        vm.startPrank(ALICE);
        nfts.mint(1, 100);

        vm.startPrank(ADMIN);
        configurationProvider.setERC1155ReserveConfig(
            1,
            DataTypes.ERC1155ReserveConfiguration({
                isActive: true,
                isFrozen: false,
                isPaused: false,
                ltv: 0.5e4,
                liquidationThreshold: 0.6e4,
                liquidationBonus: 1.1e4
            })
        );
        erc1155Oracle.setAssetPrice(1, 100e8);

        vm.startPrank(BOB);
        pool.supply(address(usdc), 10_000e6, BOB, 0);

        vm.startPrank(ALICE);
        pool.supplyERC1155(address(nfts), 1, 10, ALICE, 0);

        (uint256 totalCollateralBase,,,,,) = pool.getUserAccountData(ALICE);

        assertEq(totalCollateralBase, 10e8);

        pool.borrow(address(usdc), 5e6, 0, ALICE);

        vm.expectRevert(bytes(Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW));
        pool.borrow(address(usdc), 5e6, 0, ALICE);

        vm.startPrank(ADMIN);
        erc1155Oracle.setAssetPrice(1, 70e8);

        (,,,,, uint256 healthFactor) = pool.getUserAccountData(ALICE);

        assertLt(healthFactor, 1e18);

        vm.startPrank(CAROL);
        pool.erc1155LiquidationCall(address(nfts), 1, address(usdc), ALICE, 5e6, false);

        (totalCollateralBase,,,,,) = pool.getUserAccountData(ALICE);

        assertGt(totalCollateralBase, 0);
        assertGt(nfts.balanceOf(CAROL, 1), 0);

        vm.startPrank(ALICE);

        pool.withdrawERC1155(address(nfts), 1, type(uint256).max, ALICE);
    }
}
