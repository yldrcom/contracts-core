// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC1155PriceOracle} from "../../interfaces/IERC1155PriceOracle.sol";
import {IPoolAddressesProvider} from "../../interfaces/IPoolAddressesProvider.sol";
import {IYLDROracle} from "../../interfaces/IYLDROracle.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LiquidityAmounts} from "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {BaseERC1155CLWrapper} from "./erc1155-wrappers/BaseERC1155CLWrapper.sol";

contract ERC1155CLWrapperOracle is IERC1155PriceOracle {
    IPoolAddressesProvider public immutable addressesProvider;
    BaseERC1155CLWrapper public immutable wrapper;

    constructor(IPoolAddressesProvider _addressesProvider, BaseERC1155CLWrapper _wrapper) {
        addressesProvider = _addressesProvider;
        wrapper = _wrapper;
    }

    function _calculateSqrtPriceX96(uint256 token0Rate, uint256 token1Rate, uint8 token0Decimals, uint8 token1Decimals)
        internal
        pure
        returns (uint160 sqrtPriceX96)
    {
        // price = (10 ** token1Decimals) * token0Rate / ((10 ** token0Decimals) * token1Rate)
        // sqrtPriceX96 = sqrt(price * 2^192)

        // overflows only if token0 is 2**160 times more expensive than token1 (considered non-likely)
        uint256 factor1 = Math.mulDiv(token0Rate, 2 ** 96, token1Rate);

        // Cannot overflow if token1Decimals <= 18 and token0Decimals <= 18
        uint256 factor2 = Math.mulDiv(10 ** token1Decimals, 2 ** 96, 10 ** token0Decimals);

        uint128 factor1Sqrt = uint128(Math.sqrt(factor1));
        uint128 factor2Sqrt = uint128(Math.sqrt(factor2));

        sqrtPriceX96 = factor1Sqrt * factor2Sqrt;
    }

    function getAssetPrice(uint256 tokenId) external view returns (uint256 value) {
        (uint256 fees0, uint256 fees1) = wrapper.getPendingFees(tokenId);
        BaseERC1155CLWrapper.PositionData memory position = wrapper.getPositionData(tokenId);

        IYLDROracle oracle = IYLDROracle(addressesProvider.getPriceOracle());

        uint256 token0Price = oracle.getAssetPrice(position.token0);
        uint256 token1Price = oracle.getAssetPrice(position.token1);

        uint8 token0Decimals = IERC20Metadata(position.token0).decimals();
        uint8 token1Decimals = IERC20Metadata(position.token1).decimals();

        uint160 sqrtPriceX96 = _calculateSqrtPriceX96(token0Price, token1Price, token0Decimals, token1Decimals);

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );

        amount0 += fees0;
        amount1 += fees1;

        value = amount0 * token0Price / (10 ** token0Decimals) + amount1 * token1Price / (10 ** token1Decimals);
    }
}
