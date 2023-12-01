pragma solidity ^0.8.20;

import {BasePoolTest} from "./BasePoolTest.sol";
import {ERC1155Mock} from "../../src/mocks/ERC1155Mock.sol";
import {DataTypes} from "../../src/protocol/libraries/types/DataTypes.sol";
import {Errors} from "../../src/protocol/libraries/helpers/Errors.sol";
import {INToken} from "../../src/interfaces/INToken.sol";

contract SupplyERC1155Test is BasePoolTest {
    constructor() public {
        nfts.mint(1, 100);
        nfts.mint(2, 100);
        nfts.mint(3, 100);
    }

    function test_reverts_asset_not_listed() public {
        ERC1155Mock nonListedNFT = new ERC1155Mock();
        nonListedNFT.mint(1, 100);
        nonListedNFT.setApprovalForAll(address(pool), true);

        vm.expectRevert();
        pool.supplyERC1155(address(nonListedNFT), 1, 100, ALICE, 0);
    }

    function test_reverts_when_asset_is_not_active() public {
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
        pool.supplyERC1155(address(nfts), 1, 100, ALICE, 0);
    }

    function test_reverts_when_asset_is_paused() public {
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

        vm.expectRevert(bytes(Errors.RESERVE_PAUSED));
        pool.supplyERC1155(address(nfts), 1, 100, ALICE, 0);
    }

    function test_reverts_when_asset_is_frozen() public {
        vm.startPrank(ADMIN);
        configurationProvider.setERC1155ReserveConfig(
            1,
            DataTypes.ERC1155ReserveConfiguration({
                isActive: true,
                isFrozen: true,
                isPaused: false,
                ltv: 0.5e4,
                liquidationThreshold: 0.6e4,
                liquidationBonus: 1.1e4
            })
        );

        vm.expectRevert(bytes(Errors.RESERVE_FROZEN));
        pool.supplyERC1155(address(nfts), 1, 100, ALICE, 0);
    }

    function test_reverts_when_zero_ltv() public {
        vm.startPrank(ADMIN);
        configurationProvider.setERC1155ReserveConfig(
            1,
            DataTypes.ERC1155ReserveConfiguration({
                isActive: true,
                isFrozen: false,
                isPaused: false,
                ltv: 0,
                liquidationThreshold: 0.6e4,
                liquidationBonus: 1.1e4
            })
        );

        vm.expectRevert(bytes(Errors.ERC1155_RESERVE_CANNOT_BE_USED_AS_COLLATERAL));
        pool.supplyERC1155(address(nfts), 1, 100, ALICE, 0);
    }

    function test_reverts_zero_amount() public {
        vm.expectRevert(bytes(Errors.INVALID_AMOUNT));
        pool.supplyERC1155(address(nfts), 1, 0, ALICE, 0);
    }

    function test_reverts_more_than_allowed() public {
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

        pool.supplyERC1155(address(nfts), 1, 100, ALICE, 0);
        pool.supplyERC1155(address(nfts), 2, 100, ALICE, 0);

        vm.expectRevert(bytes(Errors.ERC1155_RESERVE_CANNOT_BE_USED_AS_COLLATERAL));
        pool.supplyERC1155(address(nfts), 3, 100, ALICE, 0);
    }

    function test_takes_asset() public {
        vm.startPrank(ADMIN);
        configurationProvider.setERC1155ReserveConfig(1, DataTypes.ERC1155ReserveConfiguration({
            isActive: true,
            isFrozen: false,
            isPaused: false,
            ltv: 0.5e4,
            liquidationThreshold: 0.6e4,
            liquidationBonus: 1.1e4
        }));

        INToken nToken = INToken(pool.getERC1155ReserveData(address(nfts)).nTokenAddress);

        vm.startPrank(ALICE);
        pool.supplyERC1155({asset: address(nfts), tokenId: 1, amount: 60, onBehalfOf: ALICE, referralCode: 0});

        assertEq(nfts.balanceOf(address(nToken), 1), 60);
        assertEq(nToken.balanceOf(ALICE, 1), 60);
        assertEq(nfts.balanceOf(ALICE, 1), 40);
    }

    function test_receives_n_token(uint256 amountToMint, uint256 amountToSupply) public {
        vm.assume(amountToMint > 0);
        vm.assume(amountToSupply > 0);
        vm.assume(amountToMint < 10 ** 30);
        vm.assume(amountToSupply <= amountToMint);

        nfts.mint(1, amountToMint);

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

        vm.startPrank(ALICE);
        pool.supplyERC1155(address(nfts), 1, amountToSupply, ALICE, 0);

        INToken nToken = INToken(pool.getERC1155ReserveData(address(nfts)).nTokenAddress);
        assertEq(nToken.balanceOf(ALICE, 1), amountToSupply);
        assertEq(nToken.totalSupply(1), amountToSupply);
    }

    function test_reserve_appears_in_used_reserves() public {
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

        vm.startPrank(ALICE);
        pool.supplyERC1155({asset: address(nfts), tokenId: 1, amount: 10, onBehalfOf: ALICE, referralCode: 0});

        DataTypes.ERC1155ReserveUsageData[] memory usedReserves = pool.getUserUsedERC1155Reserves(ALICE);
        assertEq(usedReserves.length, 1);
        assertEq(usedReserves[0].asset, address(nfts));
        assertEq(usedReserves[0].tokenId, 1);
    }

    function test_on_behalf_of_respected() public {
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

        vm.startPrank(ALICE);
        pool.supplyERC1155({asset: address(nfts), tokenId: 1, amount: 10, onBehalfOf: BOB, referralCode: 0});

        INToken nToken = INToken(pool.getERC1155ReserveData(address(nfts)).nTokenAddress);
        assertEq(nToken.balanceOf(ALICE, 1), 0);
        assertEq(nToken.totalSupply(1), 10);
        assertEq(nToken.balanceOf(BOB, 1), 10);
        assertEq(nfts.balanceOf(ALICE, 1), 90);
    }
}
