pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IPool} from "../../src/interfaces/IPool.sol";
import {IPoolConfigurator} from "../../src/interfaces/IPoolConfigurator.sol";
import {IYLDROracle} from "../../src/interfaces/IYLDROracle.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";
import {ERC1155Mock} from "../../src/mocks/ERC1155Mock.sol";
import {ERC1155ConfigurationProviderMock} from "../../src/mocks/ERC1155ConfigurationProviderMock.sol";
import {ERC1155PriceOracleMock} from "../../src/mocks/ERC1155PriceOracleMock.sol";
import {Errors} from "../../src/protocol/libraries/helpers/Errors.sol";
import {DataTypes} from "../../src/protocol/libraries/types/DataTypes.sol";
import {BaseTest} from "test/base/BaseTest.sol";
import {PoolTesting} from "test/libraries/PoolTesting.sol";
import {ChainlinkAggregatorMock} from "../../src/mocks/ChainlinkAggregatorMock.sol";

contract BasePoolTest is BaseTest {
    using PoolTesting for PoolTesting.Data;

    IPool public pool;
    IPoolConfigurator public configurator;
    IYLDROracle public oracle;

    ERC20Mock usdc;
    ERC20Mock weth;
    ERC1155Mock nfts;

    PoolTesting.Data poolTesting;

    ERC1155ConfigurationProviderMock configurationProvider;
    ERC1155PriceOracleMock erc1155Oracle;

    constructor() {
        vm.startPrank(ADMIN);

        usdc = new ERC20Mock("USD Coin", "USDC", 6);
        weth = new ERC20Mock("Wrapped Ether", "WETH", 18);
        nfts = new ERC1155Mock();

        _addAndDealToken(usdc);
        _addAndDealToken(weth);

        poolTesting.init(ADMIN, 2);

        pool = IPool(poolTesting.addressesProvider.getPool());
        configurator = IPoolConfigurator(poolTesting.addressesProvider.getPoolConfigurator());
        oracle = IYLDROracle(poolTesting.addressesProvider.getPriceOracle());

        poolTesting.addReserve(
            address(usdc),
            0.8e27,
            0,
            0.02e27,
            0.8e27,
            0.7e4,
            0.75e4,
            1.05e4,
            address(new ChainlinkAggregatorMock(1e8)),
            0.15e4
        );
        poolTesting.addReserve(
            address(weth),
            0.8e27,
            0,
            0.02e27,
            0.8e27,
            0.7e4,
            0.75e4,
            1.05e4,
            address(new ChainlinkAggregatorMock(1000e8)),
            0.15e4
        );

        address[] memory reserves = pool.getReservesList();
        for (uint256 i = 0; i < reserves.length; i++) {
            address asset = reserves[i];
            deal(asset, ADMIN, 10 ** ERC20Mock(asset).decimals());
            ERC20Mock(asset).approve(address(pool), 10 ** ERC20Mock(asset).decimals());
            pool.supply(asset, 10 ** ERC20Mock(asset).decimals(), ADMIN, 0);
        }

        configurationProvider = new ERC1155ConfigurationProviderMock();
        erc1155Oracle = new ERC1155PriceOracleMock();

        poolTesting.addERC1155Reserve(
            address(nfts), address(configurationProvider), address(erc1155Oracle), ADMIN, 0.2e4
        );
        vm.stopPrank();

        _approveAllTokensForAllCallers(address(pool));

        vm.startPrank(ALICE);
        nfts.setApprovalForAll(address(pool), true);

        vm.startPrank(BOB);
        nfts.setApprovalForAll(address(pool), true);

        vm.startPrank(CAROL);
        nfts.setApprovalForAll(address(pool), true);

        vm.startPrank(ALICE);
    }
}
