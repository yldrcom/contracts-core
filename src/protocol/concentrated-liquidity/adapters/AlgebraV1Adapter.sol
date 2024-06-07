// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {BaseCLAdapter} from "./BaseCLAdapter.sol";
import {INonfungiblePositionManager} from "@algebra/src/interfaces/INonfungiblePositionManager.sol";
import {IAlgebraFactory} from "@algebra/src/interfaces/IAlgebraFactory.sol";
import {IAlgebraPool} from "@algebra/src/interfaces/IAlgebraPool.sol";

interface IAlgebraOld {
    function globalState()
        external
        view
        returns (
            uint160 price,
            int24 tick,
            uint16 fee,
            uint16 timepointIndex,
            uint8 communityFeeToken0,
            uint8 communityFeeToken1,
            bool unlocked
        );
}

contract AlgebraV1Adapter is BaseCLAdapter {
    INonfungiblePositionManager internal immutable positionManager;
    IAlgebraFactory internal immutable factory;
    bool internal immutable isAlgebraV19;

    constructor(address _positionManager, bool _isAlgebraV19) {
        positionManager = INonfungiblePositionManager(payable(_positionManager));
        factory = IAlgebraFactory(positionManager.factory());
        isAlgebraV19 = _isAlgebraV19;
    }

    function getPositionData(uint256 tokenId) public view virtual override returns (PositionData memory) {
        (
            ,
            ,
            address token0,
            address token1,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = positionManager.positions(tokenId);

        return PositionData({
            tokenId: tokenId,
            token0: token0,
            token1: token1,
            fee: 0,
            liquidity: liquidity,
            tickLower: tickLower,
            tickUpper: tickUpper,
            tokensOwed0: tokensOwed0,
            tokensOwed1: tokensOwed1,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128
        });
    }

    function getPoolState(address pool) public view virtual override returns (uint160 sqrtPriceX96, int24 tick) {
        if (isAlgebraV19) {
            (sqrtPriceX96, tick,,,,,,) = IAlgebraPool(pool).globalState();
        } else {
            (sqrtPriceX96, tick,,,,,) = IAlgebraOld(pool).globalState();
        }
    }

    function getPoolLiquidity(address pool) public view virtual override returns (uint128 liquidity) {
        liquidity = IAlgebraPool(pool).liquidity();
    }

    function _getFeeGrowths(address pool, int24 tick)
        internal
        view
        virtual
        override
        returns (uint256 feeGrowthOutside0X128, uint256 feeGrowthOutside1X128)
    {
        (,, feeGrowthOutside0X128, feeGrowthOutside1X128,,,,) = IAlgebraPool(pool).ticks(tick);
    }

    function _getGlobalFeeGrowths(address pool)
        internal
        view
        virtual
        override
        returns (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128)
    {
        feeGrowthGlobal0X128 = IAlgebraPool(pool).totalFeeGrowth0Token();
        feeGrowthGlobal1X128 = IAlgebraPool(pool).totalFeeGrowth1Token();
    }

    function collectFees(uint256 tokenId, uint128 amount0Max, uint128 amount1Max, address receiver)
        public
        virtual
        override
        returns (uint256 amount0, uint256 amount1)
    {
        return positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: receiver,
                amount0Max: amount0Max,
                amount1Max: amount1Max
            })
        );
    }

    function increaseLiquidity(uint256 tokenId, uint256 amount0, uint256 amount1)
        public
        virtual
        override
        returns (uint256 amount0Resulted, uint256 amount1Resulted)
    {
        (, amount0Resulted, amount1Resulted) = positionManager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
    }

    function decreaseLiquidity(uint256 tokenId, uint128 liquidity)
        public
        virtual
        override
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
    }

    function getPool(PositionData memory position) public view virtual override returns (address) {
        return factory.poolByPair(position.token0, position.token1);
    }

    function getPositionManager() public view override returns (address) {
        return address(positionManager);
    }

    function mintPosition(MintParams memory params)
        public
        override
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        (tokenId, liquidity, amount0, amount1) = positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: params.token0,
                token1: params.token1,
                tickLower: params.tickLower,
                tickUpper: params.tickUpper,
                amount0Desired: params.amount0Desired,
                amount1Desired: params.amount1Desired,
                amount0Min: params.amount0Min,
                amount1Min: params.amount1Min,
                recipient: params.recipient,
                deadline: params.deadline
            })
        );
    }

    function getTickSpacing(address pool) public view virtual override returns (int24) {
        return IAlgebraPool(pool).tickSpacing();
    }

    function getLowLevelPositionData(address pool, address owner, int24 tickLower, int24 tickUpper)
        public
        view
        virtual
        override
        returns (
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        // https://github.com/cryptoalgebra/AlgebraV1/blob/789384bc5084dd694f3d1e189250491086e44653/src/core/contracts/AlgebraPool.sol#L403
        bytes32 key;
        assembly {
            key := or(shl(24, or(shl(24, owner), and(tickLower, 0xFFFFFF))), and(tickUpper, 0xFFFFFF))
        }
        (liquidity,, feeGrowthInside0LastX128, feeGrowthInside1LastX128, tokensOwed0, tokensOwed1) =
            IAlgebraPool(pool).positions(key);
    }
}
