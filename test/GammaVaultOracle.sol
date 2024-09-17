pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GammaVaultOracle, IHypervisor} from "../src/protocol/concentrated-liquidity/GammaVaultOracle.sol";
import {IPoolAddressesProvider} from "../src/interfaces/IPoolAddressesProvider.sol";
import {AlgebraV1Adapter} from "../src/protocol/concentrated-liquidity/adapters/AlgebraV1Adapter.sol";
import {UniswapV3Adapter} from "../src/protocol/concentrated-liquidity/adapters/UniswapV3Adapter.sol";

contract GammaVaultOracleTest is Test {
    IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(0x488402D92f32eEdA5cf61521ADf7f8e8f1DcaC20);
    AlgebraV1Adapter quickswapAdapter;
    UniswapV3Adapter uniAdapter;

    constructor() {
        vm.createSelectFork("polygon");
        vm.rollFork(61301205);
        vm.stopPrank();

        quickswapAdapter = new AlgebraV1Adapter(0x8eF88E4c7CfbbaC1C163f7eddd4B578792201de6, false);
        uniAdapter = new UniswapV3Adapter(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    }

    function test_quickswap() public {
        GammaVaultOracle oracle =
            new GammaVaultOracle(IHypervisor(0x1cf4293125913cB3Dea4aD7f2bb4795B9e896CE9), quickswapAdapter, addressesProvider);
        assertGt(oracle.latestAnswer(), 0);
    }

    function test_uniswap() public {
        GammaVaultOracle oracle =
            new GammaVaultOracle(IHypervisor(0x1Fd452156b12FB5D74680C5Ff166303E6dd12A78), uniAdapter, addressesProvider);
        assertGt(oracle.latestAnswer(), 0);
    }
}
