pragma solidity ^0.8.20;

import {BasePoolTest} from "./BasePoolTest.sol";
import {ERC1155Mock} from "../../src/mocks/ERC1155Mock.sol";
import {DataTypes} from "../../src/protocol/libraries/types/DataTypes.sol";
import {Errors} from "../../src/protocol/libraries/helpers/Errors.sol";
import {INToken} from "../../src/interfaces/INToken.sol";
import {PoolTesting} from "../libraries/PoolTesting.sol";

contract WithdrawERC1155Test is BasePoolTest {
    using PoolTesting for PoolTesting.Data;

    constructor() {
        nfts.mint(1, 100);
        nfts.mint(2, 100);
        nfts.mint(3, 100);

        vm.startPrank(ADMIN);
        DataTypes.ERC1155ReserveConfiguration memory config = DataTypes.ERC1155ReserveConfiguration({
            isActive: true,
            isFrozen: false,
            isPaused: false,
            ltv: 0.5e4,
            liquidationThreshold: 0.6e4,
            liquidationBonus: 1.1e4
        });
        configurationProvider.setERC1155ReserveConfig(1, config);
        configurationProvider.setERC1155ReserveConfig(2, config);
        configurationProvider.setERC1155ReserveConfig(3, config);

        vm.startPrank(ALICE);
        pool.supplyERC1155({asset: address(nfts), tokenId: 1, amount: 100, onBehalfOf: ALICE, referralCode: 0});
        pool.supplyERC1155({asset: address(nfts), tokenId: 2, amount: 100, onBehalfOf: ALICE, referralCode: 0});
    }

    function test_reverts_reserve_not_active() public {
        vm.startPrank(ADMIN);
        configurationProvider.setERC1155ReserveConfig(
            1,
            DataTypes.ERC1155ReserveConfiguration({
                isActive: false,
                isFrozen: false,
                isPaused: false,
                ltv: 0.5e4,
                liquidationThreshold: 0.6e4,
                liquidationBonus: 1.1e4
            })
        );
        vm.startPrank(ALICE);
        vm.expectRevert(bytes(Errors.RESERVE_INACTIVE));
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 100, to: ALICE});
    }

    function test_reverts_reserve_paused() public {
        vm.startPrank(ADMIN);
        configurationProvider.setERC1155ReserveConfig(
            1,
            DataTypes.ERC1155ReserveConfiguration({
                isActive: true,
                isFrozen: false,
                isPaused: true,
                ltv: 0.5e4,
                liquidationThreshold: 0.6e4,
                liquidationBonus: 1.1e4
            })
        );

        vm.startPrank(ALICE);
        vm.expectRevert(bytes(Errors.RESERVE_PAUSED));
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 100, to: ALICE});
    }

    function test_reverts_invalid_amount() public {
        vm.expectRevert(bytes(Errors.INVALID_AMOUNT));
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 0, to: ALICE});

        vm.expectRevert(bytes(Errors.NOT_ENOUGH_AVAILABLE_USER_BALANCE));
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 101, to: ALICE});
    }

    function test_reverts_HF_check_fail() public {
        erc1155Oracle.setAssetPrice(1, 1000e8);

        vm.startPrank(BOB);
        pool.supply({asset: address(usdc), amount: 1000e6, onBehalfOf: BOB, referralCode: 0});

        vm.startPrank(ALICE);
        pool.borrow({asset: address(usdc), amount: 500e6, onBehalfOf: ALICE, referralCode: 0});

        erc1155Oracle.setAssetPrice(2, 700e8);

        vm.expectRevert(bytes(Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD));
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 100, to: ALICE});
    }

    function test_reverts_LTV_check_fail_ERC20_zero_LTV() public {
        erc1155Oracle.setAssetPrice(1, 1000e8);

        vm.startPrank(BOB);
        pool.supply({asset: address(weth), amount: 1e18, onBehalfOf: BOB, referralCode: 0});

        vm.startPrank(ALICE);
        pool.supply({asset: address(usdc), amount: 1000e6, onBehalfOf: ALICE, referralCode: 0});
        pool.borrow({asset: address(weth), amount: 0.1e18, onBehalfOf: ALICE, referralCode: 0});

        vm.startPrank(ADMIN);
        poolTesting.configureReserveAsCollateral({
            asset: address(usdc),
            ltv: 0,
            liquidationThreshold: 0.1e4,
            liquidationBonus: 1.05e4
        });

        vm.startPrank(ALICE);
        vm.expectRevert(bytes(Errors.LTV_VALIDATION_FAILED));
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 1, to: ALICE});
    }

    function test_reverts_LTV_check_fail_ERC1155_zero_LTV() public {
        erc1155Oracle.setAssetPrice(1, 1000e8);

        vm.startPrank(BOB);
        pool.supply({asset: address(weth), amount: 1e18, onBehalfOf: BOB, referralCode: 0});

        vm.startPrank(ALICE);
        pool.supply({asset: address(usdc), amount: 1000e6, onBehalfOf: ALICE, referralCode: 0});
        pool.borrow({asset: address(weth), amount: 0.1e18, onBehalfOf: ALICE, referralCode: 0});

        vm.startPrank(ADMIN);
        poolTesting.configureReserveAsCollateral({
            asset: address(usdc),
            ltv: 0,
            liquidationThreshold: 0.1e4,
            liquidationBonus: 1.05e4
        });

        vm.startPrank(ALICE);
        vm.expectRevert(bytes(Errors.LTV_VALIDATION_FAILED));
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 1, to: ALICE});
    }

    function test_transfers_asset() public {
        vm.startPrank(ALICE);
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 1, to: ALICE});

        assertEq(nfts.balanceOf(ALICE, 1), 1);
    }

    function test_burns_ntoken() public {
        INToken nToken = INToken(pool.getERC1155ReserveData(address(nfts)).nTokenAddress);
        uint256 supplyBefore = nToken.totalSupply(1);
        uint256 aliceBalanceBefore = nToken.balanceOf(ALICE, 1);
        uint256 nftBalanceBefore = nfts.balanceOf(address(nToken), 1);

        vm.startPrank(ALICE);
        pool.withdrawERC1155({asset: address(nfts), tokenId: 1, amount: 1, to: ALICE});

        assertEq(nToken.totalSupply(1), supplyBefore - 1);
        assertEq(nToken.balanceOf(ALICE, 1), aliceBalanceBefore - 1);
        assertEq(nfts.balanceOf(address(nToken), 1), nftBalanceBefore - 1);
    }
}
