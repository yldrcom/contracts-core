pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {PoolConfigurator} from "src/protocol/pool/PoolConfigurator.sol";
import {IPoolConfigurator, ConfiguratorInputTypes} from "src/interfaces/IPoolConfigurator.sol";
import {Pool} from "src/protocol/pool/Pool.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {PoolAddressesProvider} from "src/protocol/configuration/PoolAddressesProvider.sol";
import {ACLManager} from "src/protocol/configuration/ACLManager.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {YToken} from "src/protocol/tokenization/YToken.sol";
import {VariableDebtToken} from "src/protocol/tokenization/VariableDebtToken.sol";
import {DefaultReserveInterestRateStrategy} from "src/protocol/pool/DefaultReserveInterestRateStrategy.sol";
import {YLDROracleMock} from "./mocks/YLDROracleMock.sol";
import {Errors} from "src/protocol/libraries/helpers/Errors.sol";

contract PoolTest is Test {
    PoolAddressesProvider addressesProvider;
    ACLManager aclManager;
    YLDROracleMock oracle;
    ERC20Mock usdc;
    ERC20Mock weth;

    address ADMIN;
    address ALICE;
    address BOB;
    address CAROL;

    IPool pool;

    constructor() {
        ADMIN = vm.addr(0xad1119);
        ALICE = vm.addr(0xa111ce);
        BOB = vm.addr(0xb0b);
        CAROL = vm.addr(0xca10c);

        usdc = new ERC20Mock("USD Coin", "USDC", 6);
        weth = new ERC20Mock("Wrapped Ether", "WETH", 18);

        vm.startPrank(ADMIN);

        addressesProvider = new PoolAddressesProvider("YLDR", ADMIN);
        addressesProvider.setACLAdmin(ADMIN);

        aclManager = new ACLManager(addressesProvider);
        oracle = new YLDROracleMock();

        aclManager.addPoolAdmin(ADMIN);
        addressesProvider.setACLManager(address(aclManager));
        addressesProvider.setPoolImpl(address(new Pool(addressesProvider)));
        addressesProvider.setPoolConfiguratorImpl(address(new PoolConfigurator()));
        addressesProvider.setPriceOracle(address(oracle));

        address yTokenImpl = address(new YToken(Pool(addressesProvider.getPool())));
        address variableDebtTokenImpl = address(new VariableDebtToken(Pool(addressesProvider.getPool())));

        ConfiguratorInputTypes.InitReserveInput[] memory reserves = new ConfiguratorInputTypes.InitReserveInput[](2);
        reserves[0] = ConfiguratorInputTypes.InitReserveInput({
            yTokenImpl: yTokenImpl,
            variableDebtTokenImpl: variableDebtTokenImpl,
            underlyingAssetDecimals: usdc.decimals(),
            interestRateStrategyAddress: address(
                new DefaultReserveInterestRateStrategy(addressesProvider, 0.8e27, 0, 0.02e27, 0.8e27)
                ),
            underlyingAsset: address(usdc),
            treasury: ADMIN,
            incentivesController: address(0),
            yTokenName: "YLDR Interest bearing USDC",
            yTokenSymbol: "yUSDC",
            variableDebtTokenName: "YLDR Variable Debt USDC",
            variableDebtTokenSymbol: "vUSDC",
            params: ""
        });
        reserves[1] = ConfiguratorInputTypes.InitReserveInput({
            yTokenImpl: yTokenImpl,
            variableDebtTokenImpl: variableDebtTokenImpl,
            underlyingAssetDecimals: weth.decimals(),
            interestRateStrategyAddress: address(
                new DefaultReserveInterestRateStrategy(addressesProvider, 0.8e27, 0, 0.02e27, 0.8e27)
                ),
            underlyingAsset: address(weth),
            treasury: ADMIN,
            incentivesController: address(0),
            yTokenName: "YLDR Interest bearing WETH",
            yTokenSymbol: "yWETH",
            variableDebtTokenName: "YLDR Variable Debt WETH",
            variableDebtTokenSymbol: "vWETH",
            params: ""
        });
        IPoolConfigurator(addressesProvider.getPoolConfigurator()).initReserves(reserves);
        IPoolConfigurator(addressesProvider.getPoolConfigurator()).setReserveBorrowing(address(usdc), true);
        IPoolConfigurator(addressesProvider.getPoolConfigurator()).setReserveBorrowing(address(weth), true);

        IPoolConfigurator(addressesProvider.getPoolConfigurator()).configureReserveAsCollateral(
            address(usdc), 0.7e4, 0.75e4, 1.05e4
        );
        IPoolConfigurator(addressesProvider.getPoolConfigurator()).configureReserveAsCollateral(
            address(weth), 0.7e4, 0.75e4, 1.05e4
        );

        oracle.setAssetPrice(address(usdc), 1e8);
        oracle.setAssetPrice(address(weth), 1000e8);
        vm.stopPrank();

        usdc.mint(ALICE, 1_000_000e6);
        usdc.mint(BOB, 1_000_000e6);
        usdc.mint(CAROL, 1_000_000e6);
        weth.mint(BOB, 1000e18);
        weth.mint(ALICE, 1000e18);
        weth.mint(CAROL, 1000e18);

        pool = IPool(addressesProvider.getPool());

        vm.startPrank(ALICE);
        usdc.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        vm.startPrank(BOB);
        usdc.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        vm.startPrank(CAROL);
        usdc.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);
    }

    function _test_supply_borrow_repay_withdraw(bool direction) internal {
        (address collateral, address debt) = direction ? (address(usdc), address(weth)) : (address(weth), address(usdc));
        vm.startPrank(ALICE);
        pool.supply(address(usdc), 10_000e6, ALICE, 0);

        vm.startPrank(BOB);
        pool.supply(address(weth), 10e18, BOB, 0);
        pool.borrow(address(usdc), 1_000e6, 0, BOB);
        pool.repay(address(usdc), 1_000e6, BOB);
        pool.withdraw(address(weth), 10e18, BOB);
    }

    function test_supply_borrow_repay_withdraw() public {
        _test_supply_borrow_repay_withdraw(true);
        _test_supply_borrow_repay_withdraw(false);
    }

    function test_supply_borrow_liquidate() public {
        vm.startPrank(ALICE);
        pool.supply(address(usdc), 10_000e6, ALICE, 0);

        vm.startPrank(BOB);
        pool.supply(address(weth), 10e18, BOB, 0);
        pool.borrow(address(usdc), 1_000e6, 0, BOB);

        vm.expectRevert(bytes(Errors.COLLATERAL_CANNOT_COVER_NEW_BORROW));
        pool.borrow(address(usdc), 8_000e6, 0, BOB);

        vm.startPrank(ADMIN);
        oracle.setAssetPrice(address(weth), 100e8);

        vm.startPrank(CAROL);
        pool.liquidationCall(address(weth), address(usdc), BOB, 8_000e6, false);
        vm.stopPrank();
    }
}
