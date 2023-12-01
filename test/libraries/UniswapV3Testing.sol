pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Utils} from "test/libraries/Utils.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library UniswapV3Testing {
    using SafeERC20 for IERC20Metadata;

    struct Data {
        INonfungiblePositionManager positionManager;
        IUniswapV3Factory factory;
    }

    uint24 constant DEFAULT_USED_FEE = 500;

    function init(Data storage self, INonfungiblePositionManager _positionManager) internal {
        self.positionManager = _positionManager;
        self.factory = IUniswapV3Factory(_positionManager.factory());
    }

    enum PositionType {
        Both,
        Only0,
        Only1
    }

    function acquireUniswapPosition(
        Data storage self,
        address token0,
        address token1,
        uint256 amount0Max,
        uint256 amount1Max,
        PositionType posType
    ) internal returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
        IUniswapV3Pool pool = IUniswapV3Pool(self.factory.getPool(token0, token1, DEFAULT_USED_FEE));

        IERC20Metadata(token0).forceApprove(address(self.positionManager), type(uint256).max);
        IERC20Metadata(token1).forceApprove(address(self.positionManager), type(uint256).max);

        (, int24 tick,,,,,) = pool.slot0();
        tick -= tick % pool.tickSpacing();

        int24 tickLower;
        int24 tickUpper;
        if (posType == PositionType.Both) {
            tickLower = tick - 200;
            tickUpper = tick + 200;
        } else if (posType == PositionType.Only0) {
            tickLower = tick + 200;
            tickUpper = tick + 400;
        } else if (posType == PositionType.Only1) {
            tickLower = tick - 400;
            tickUpper = tick - 200;
        }

        (tokenId,, amount0, amount1) = self.positionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(token0),
                token1: address(token1),
                fee: DEFAULT_USED_FEE,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Max, // amounts don't really matter, position will have both anyway
                amount1Desired: amount1Max,
                amount0Min: 0,
                amount1Min: 0,
                recipient: Utils.getCurrentCaller(),
                deadline: block.timestamp
            })
        );
    }
}
