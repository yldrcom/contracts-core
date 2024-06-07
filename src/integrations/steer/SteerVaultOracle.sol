// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IChainlinkAggregator} from "../../interfaces/ext/IChainlinkAggregator.sol";
import {ISteerVault} from "../../interfaces/ext/ISteerVault.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseCLAdapter} from "../../protocol/concentrated-liquidity/adapters/BaseCLAdapter.sol";
import {IPoolAddressesProvider} from "../../interfaces/IPoolAddressesProvider.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IYLDROracle} from "../../interfaces/IYLDROracle.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

contract SteerVaultOracle is IChainlinkAggregator {
    uint256 internal constant FEE_DIVISOR = 100_00;

    IPoolAddressesProvider public immutable addressesProvider;
    ISteerVault public immutable vault;
    IERC20Metadata public immutable token0;
    IERC20Metadata public immutable token1;
    uint8 public immutable decimals0;
    uint8 public immutable decimals1;
    address public immutable pool;
    BaseCLAdapter public immutable adapter;

    constructor(ISteerVault _vault, BaseCLAdapter _adapter, IPoolAddressesProvider _addressesProvider) {
        vault = _vault;
        token0 = IERC20Metadata(_vault.token0());
        token1 = IERC20Metadata(_vault.token1());
        pool = _vault.pool();
        adapter = _adapter;
        addressesProvider = _addressesProvider;
        decimals0 = token0.decimals();
        decimals1 = token1.decimals();
    }

    function latestAnswer() external view returns (int256) {
        IYLDROracle oracle = IYLDROracle(addressesProvider.getPriceOracle());
        (int24[] memory lowerTicks, int24[] memory upperTicks,) = vault.getPositions();
        uint256 token0Rate = oracle.getAssetPrice(address(token0));
        uint256 token1Rate = oracle.getAssetPrice(address(token1));
        uint160 sqrtPriceX96 = _calculateSqrtPriceX96(token0Rate, token1Rate);

        uint256 total0 = token0.balanceOf(address(vault));
        uint256 total1 = token1.balanceOf(address(vault));
        uint256 totalFees0;
        uint256 totalFees1;

        for (uint256 i = 0; i < lowerTicks.length; i++) {
            int24 tickLower = lowerTicks[i];
            int24 tickUpper = upperTicks[i];

            (uint128 liquidity,,, uint256 fees0, uint256 fees1) =
                adapter.getLowLevelPositionData(pool, address(vault), tickLower, tickUpper);
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
            );

            total0 += amount0;
            total1 += amount1;

            totalFees0 += fees0;
            totalFees1 += fees1;
        }

        total0 += totalFees0 * (FEE_DIVISOR - vault.TOTAL_FEE()) / FEE_DIVISOR;
        total1 += totalFees1 * (FEE_DIVISOR - vault.TOTAL_FEE()) / FEE_DIVISOR;

        uint256 totalValue = token0Rate * total0 / (10 ** decimals0) + token1Rate * total1 / (10 ** decimals1);
        return int256(totalValue * (10 ** vault.decimals()) / vault.totalSupply());
    }

    function _calculateSqrtPriceX96(uint256 token0Rate, uint256 token1Rate)
        internal
        view
        returns (uint160 sqrtPriceX96)
    {
        // price = (10 ** token1Decimals) * token0Rate / ((10 ** token0Decimals) * token1Rate)
        // sqrtPriceX96 = sqrt(price * 2^192)

        // overflows only if token0 is 2**160 times more expensive than token1 (considered non-likely)
        uint256 factor1 = Math.mulDiv(token0Rate, 2 ** 96, token1Rate);

        // Cannot overflow if token1Decimals <= 18 and token0Decimals <= 18
        uint256 factor2 = Math.mulDiv(10 ** decimals1, 2 ** 96, 10 ** decimals0);

        uint128 factor1Sqrt = uint128(Math.sqrt(factor1));
        uint128 factor2Sqrt = uint128(Math.sqrt(factor2));

        sqrtPriceX96 = factor1Sqrt * factor2Sqrt;
    }
}
