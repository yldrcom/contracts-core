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
import {BaseCLAdapterTest} from "./BaseCLAdapter.t.sol";
import {UniswapV3Adapter} from "../src/protocol/concentrated-liquidity/adapters/UniswapV3Adapter.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract UniswapV3AdapterTest is BaseCLAdapterTest {
    using CLAdapterWrapper for BaseCLAdapter;

    IUniswapV3Factory factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    UniswapV3Adapter adapter;
    IERC20Metadata usdc = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata weth = IERC20Metadata(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    constructor() {
        vm.createSelectFork("mainnet");
        vm.rollFork(18630167);
        vm.stopPrank();

        adapter = new UniswapV3Adapter(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    }

    function _getAdapter() internal view override returns (BaseCLAdapter) {
        return adapter;
    }

    function _getUSDC() internal view override returns (IERC20Metadata) {
        return usdc;
    }

    function _getWETH() internal view override returns (IERC20Metadata) {
        return weth;
    }

    function _getFee() internal pure override returns (uint24) {
        return 500;
    }

    function _getPool(address token0, address token1, uint24 fee) internal view override returns (address) {
        return factory.getPool(token0, token1, fee);
    }
}
