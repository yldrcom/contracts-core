pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AlgebraV1Adapter} from "../src/protocol/concentrated-liquidity/adapters/AlgebraV1Adapter.sol";
import {BaseTest} from "test/base/BaseTest.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {BaseCLAdapter} from "../src/protocol/concentrated-liquidity/adapters/BaseCLAdapter.sol";
import {BaseCLAdapterTest} from "./BaseCLAdapter.t.sol";
import {INonfungiblePositionManager} from "@algebra/src/interfaces/INonfungiblePositionManager.sol";
import {IAlgebraFactory} from "@algebra/src/interfaces/IAlgebraFactory.sol";

contract BaseAlgebraV1AdapterTest is BaseCLAdapterTest {
    IAlgebraFactory factory;
    AlgebraV1Adapter adapter;
    IERC20Metadata usdc;
    IERC20Metadata weth;

    constructor(
        string memory forkUrl,
        uint256 forkBlock,
        address positionManager,
        address _usdc,
        address _weth,
        bool isAlgebraV19
    ) {
        vm.createSelectFork(forkUrl);
        vm.rollFork(forkBlock);
        vm.stopPrank();

        usdc = IERC20Metadata(_usdc);
        weth = IERC20Metadata(_weth);

        adapter = new AlgebraV1Adapter(address(positionManager), isAlgebraV19);
        factory = IAlgebraFactory(INonfungiblePositionManager(payable(positionManager)).factory());
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
        return 0;
    }

    function _getPool(address token0, address token1, uint24) internal view override returns (address) {
        return factory.poolByPair(token0, token1);
    }
}

contract CamelotAdapterTest is
    BaseAlgebraV1AdapterTest(
        "arbitrum_one",
        197388780,
        0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15,
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831,
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1,
        true
    )
{}

contract QuickswapAdapterTest is
    BaseAlgebraV1AdapterTest(
        "polygon",
        57569589,
        0x8eF88E4c7CfbbaC1C163f7eddd4B578792201de6,
        0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
        0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619,
        false
    )
{}
