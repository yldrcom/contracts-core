pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {Errors} from "../src/protocol/libraries/helpers/Errors.sol";
import {DataTypes} from "../src/protocol/libraries/types/DataTypes.sol";
import {ERC1155CLWrapper} from "../src/protocol/concentrated-liquidity/ERC1155CLWrapper.sol";
import {UniswapV3Adapter} from "../src/protocol/concentrated-liquidity/adapters/UniswapV3Adapter.sol";
import {ERC1155CLWrapperConfigurationProvider} from
    "../src/protocol/concentrated-liquidity/ERC1155CLWrapperConfigurationProvider.sol";
import {ERC1155CLWrapperOracle} from "../src/protocol/concentrated-liquidity/ERC1155CLWrapperOracle.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UniswapV3Testing} from "test/libraries/UniswapV3Testing.sol";
import {PoolTesting} from "test/libraries/PoolTesting.sol";
import {BaseTest} from "test/base/BaseTest.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {CLAdapterWrapper} from "../src/protocol/concentrated-liquidity/CLAdapterWrapper.sol";
import {BaseCLAdapter} from "../src/protocol/concentrated-liquidity/adapters/BaseCLAdapter.sol";

abstract contract BaseCLAdapterTest is BaseTest {
    using CLAdapterWrapper for BaseCLAdapter;

    function _getAdapter() internal view virtual returns (BaseCLAdapter);
    function _getUSDC() internal view virtual returns (IERC20Metadata);
    function _getWETH() internal view virtual returns (IERC20Metadata);
    function _getFee() internal view virtual returns (uint24);
    function _getPool(address token0, address token1, uint24 fee) internal view virtual returns (address);

    function _sortTokens() internal view returns (address, address) {
        IERC20Metadata usdc = _getUSDC();
        IERC20Metadata weth = _getWETH();
        return (address(usdc) < address(weth)) ? (address(usdc), address(weth)) : (address(weth), address(usdc));
    }

    function _buildMintParams() internal view returns (BaseCLAdapter.MintParams memory) {
        IERC20Metadata usdc = _getUSDC();
        BaseCLAdapter adapter = _getAdapter();

        uint24 fee = _getFee();
        (address token0, address token1) = _sortTokens();

        address pool = _getPool(token0, token1, fee);
        (, int24 currentTick) = adapter.getPoolState(pool);
        int24 tickSpacing = adapter.getTickSpacing(pool);

        int24 tickLower = currentTick - 1000;
        int24 tickUpper = currentTick + 1000;
        tickLower -= tickLower % tickSpacing;
        tickUpper -= tickUpper % tickSpacing;

        return BaseCLAdapter.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            amount0Desired: address(usdc) == token0 ? (10_000 * 1e6) : 2 * 1e18,
            amount1Desired: address(usdc) == token1 ? (10_000 * 1e6) : 2 * 1e18,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: type(uint256).max
        });
    }

    function test() public {
        {
            IERC20Metadata usdc = _getUSDC();
            IERC20Metadata weth = _getWETH();

            deal(address(usdc), address(this), 1_000_000 * 1e6);
            deal(address(weth), address(this), 1_000 * 1e18);

            usdc.approve(_getAdapter().getPositionManager(), type(uint256).max);
            weth.approve(_getAdapter().getPositionManager(), type(uint256).max);
        }

        BaseCLAdapter.MintParams memory params = _buildMintParams();
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
        {
            (address token0, address token1) = _sortTokens();
            uint256 token0BalanceBefore = IERC20Metadata(token0).balanceOf(address(this));
            uint256 token1BalanceBefore = IERC20Metadata(token1).balanceOf(address(this));

            (tokenId, liquidity, amount0, amount1) = _getAdapter().delegateMintPosition(params);

            uint256 token0BalanceAfter = IERC20Metadata(token0).balanceOf(address(this));
            uint256 token1BalanceAfter = IERC20Metadata(token1).balanceOf(address(this));

            assertEq(token0BalanceBefore - token0BalanceAfter, amount0);
            assertEq(token1BalanceBefore - token1BalanceAfter, amount1);
        }

        {
            BaseCLAdapter.PositionData memory position = _getAdapter().getPositionData(tokenId);
            assertEq(position.tokenId, tokenId);
            assertEq(position.token0, params.token0);
            assertEq(position.token1, params.token1);
            assertEq(position.fee, params.fee);
            assertEq(position.liquidity, liquidity);
        }

        {
            (address token0, address token1) = _sortTokens();

            uint256 token0BalanceBefore = IERC20Metadata(token0).balanceOf(address(this));
            uint256 token1BalanceBefore = IERC20Metadata(token1).balanceOf(address(this));

            (uint256 amount0Increase, uint256 amount1Increase) =
                _getAdapter().delegateIncreaseLiquidity(tokenId, amount0, amount1);

            uint256 token0BalanceAfter = IERC20Metadata(token0).balanceOf(address(this));
            uint256 token1BalanceAfter = IERC20Metadata(token1).balanceOf(address(this));

            assertEq(token0BalanceBefore - token0BalanceAfter, amount0Increase);
            assertEq(token1BalanceBefore - token1BalanceAfter, amount1Increase);

            amount0 += amount0Increase;
            amount1 += amount1Increase;
            liquidity = _getAdapter().getPositionData(tokenId).liquidity;
        }

        {
            (address token0, address token1) = _sortTokens();

            (uint256 amount0Decrease, uint256 amount1Decrease) =
                _getAdapter().delegateDecreaseLiquidity(tokenId, liquidity);
            assertApproxEqAbs(amount0Decrease, amount0, 2);
            assertApproxEqAbs(amount1Decrease, amount1, 2);

            uint256 token0BalanceBefore = IERC20Metadata(token0).balanceOf(address(this));
            uint256 token1BalanceBefore = IERC20Metadata(token1).balanceOf(address(this));

            (uint256 amount0Sent, uint256 amount1Sent) =
                _getAdapter().delegateCollectFees(tokenId, type(uint128).max, type(uint128).max, address(this));

            uint256 token0BalanceAfter = IERC20Metadata(token0).balanceOf(address(this));
            uint256 token1BalanceAfter = IERC20Metadata(token1).balanceOf(address(this));

            assertEq(amount0Sent, amount0Decrease);
            assertEq(amount1Sent, amount1Decrease);
            assertEq(token0BalanceAfter - token0BalanceBefore, amount0Decrease);
            assertEq(token1BalanceAfter - token1BalanceBefore, amount1Decrease);
        }
    }
}
