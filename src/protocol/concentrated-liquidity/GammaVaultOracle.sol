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
import {BaseALMOracle} from "./BaseALMOracle.sol";
import {IHypervisor} from "../../interfaces/ext/IHypervisor.sol";

contract GammaVaultOracle is BaseALMOracle {
    uint256 internal constant FEE_DIVISOR = 100_00;

    IPoolAddressesProvider public immutable addressesProvider;
    IHypervisor public immutable vault;
    IERC20Metadata public immutable token0;
    IERC20Metadata public immutable token1;
    uint8 public immutable decimals0;
    uint8 public immutable decimals1;
    address public immutable pool;
    BaseCLAdapter public immutable adapter;

    constructor(IHypervisor _vault, BaseCLAdapter _adapter, IPoolAddressesProvider _addressesProvider) {
        vault = _vault;
        token0 = IERC20Metadata(_vault.token0());
        token1 = IERC20Metadata(_vault.token1());
        pool = _vault.pool();
        adapter = _adapter;
        addressesProvider = _addressesProvider;
        decimals0 = token0.decimals();
        decimals1 = token1.decimals();
    }

    function _getPositionAmounts(int24 lower, int24 upper, uint160 sqrtPriceX96)
        internal
        view
        returns (uint256, uint256)
    {
        uint256 fee = vault.fee();
        (uint128 liquidity,,, uint256 fees0, uint256 fees1) =
            adapter.getLowLevelPositionData(pool, address(vault), lower, upper);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(lower), TickMath.getSqrtRatioAtTick(upper), liquidity
        );
        amount0 += fees0 - fees0 / fee;
        amount1 += fees1 - fees1 / fee;
        return (amount0, amount1);
    }

    function latestAnswer() external view returns (int256) {
        IYLDROracle oracle = IYLDROracle(addressesProvider.getPriceOracle());
        uint256 token0Rate = oracle.getAssetPrice(address(token0));
        uint256 token1Rate = oracle.getAssetPrice(address(token1));
        uint160 sqrtPriceX96 = _calculateSqrtPriceX96(token0Rate, token1Rate);

        (uint256 base0, uint256 base1) = _getPositionAmounts(vault.baseLower(), vault.baseUpper(), sqrtPriceX96);
        (uint256 limit0, uint256 limit1) = _getPositionAmounts(vault.limitLower(), vault.limitUpper(), sqrtPriceX96);

        uint256 total0 = token0.balanceOf(address(vault)) + base0 + limit0;
        uint256 total1 = token1.balanceOf(address(vault)) + base1 + limit1;

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
