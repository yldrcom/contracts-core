pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SteerVaultOracle, ISteerVault} from "../src/integrations/steer/SteerVaultOracle.sol";
import {IPoolAddressesProvider} from "../src/interfaces/IPoolAddressesProvider.sol";
import {UniswapV3Adapter} from "../src/protocol/concentrated-liquidity/adapters/UniswapV3Adapter.sol";

contract SteerVaultOracleTest is Test {
    IPoolAddressesProvider addressesProvider = IPoolAddressesProvider(0x488402D92f32eEdA5cf61521ADf7f8e8f1DcaC20);
    SteerVaultOracle oracle;
    UniswapV3Adapter adapter;

    constructor() {
        vm.createSelectFork("polygon");
        vm.rollFork(57567473);
        vm.stopPrank();

        adapter = new UniswapV3Adapter(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        oracle =
            new SteerVaultOracle(ISteerVault(0x86A143708A3Bb2dC76312bf020d56E840c2D4628), adapter, addressesProvider);
    }

    function test() public {
        assertGt(oracle.latestAnswer(), 0);
    }
}
