pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {PoolConfigurator} from "src/protocol/pool/PoolConfigurator.sol";
import {IPoolConfigurator, ConfiguratorInputTypes} from "src/interfaces/IPoolConfigurator.sol";
import {Pool} from "src/protocol/pool/Pool.sol";
import {IPool} from "src/interfaces/IPool.sol";
import {PoolAddressesProvider} from "src/protocol/configuration/PoolAddressesProvider.sol";
import {ACLManager} from "src/protocol/configuration/ACLManager.sol";
import {ERC20Mock} from "src/mocks/ERC20Mock.sol";
import {ERC1155Mock} from "src/mocks/ERC1155Mock.sol";
import {ERC1155ConfigurationProviderMock} from "src/mocks/ERC1155ConfigurationProviderMock.sol";
import {YToken} from "src/protocol/tokenization/YToken.sol";
import {NToken} from "src/protocol/tokenization/NToken.sol";
import {VariableDebtToken} from "src/protocol/tokenization/VariableDebtToken.sol";
import {DefaultReserveInterestRateStrategy} from "src/protocol/pool/DefaultReserveInterestRateStrategy.sol";
import {YLDROracle} from "src/misc/YLDROracle.sol";
import {Errors} from "src/protocol/libraries/helpers/Errors.sol";
import {DataTypes} from "src/protocol/libraries/types/DataTypes.sol";
import {
    ERC1155UniswapV3Wrapper,
    INonfungiblePositionManager
} from "src/protocol/concentrated-liquidity/ERC1155UniswapV3Wrapper.sol";
import {ERC1155UniswapV3ConfigurationProvider} from
    "src/protocol/concentrated-liquidity/ERC1155UniswapV3ConfigurationProvider.sol";
import {ERC1155UniswapV3Oracle} from "src/protocol/concentrated-liquidity/ERC1155UniswapV3Oracle.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {UniswapV3Testing} from "test/libraries/UniswapV3Testing.sol";
import {BaseTest} from "test/base/BaseTest.sol";

contract UniswapV3WrapperTest is BaseTest {
    using UniswapV3Testing for UniswapV3Testing.Data;

    PoolAddressesProvider addressesProvider;
    ACLManager aclManager;
    YLDROracle oracle;
    IERC20Metadata usdc = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Metadata weth = IERC20Metadata(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Metadata usdt = IERC20Metadata(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    ERC1155UniswapV3Wrapper uniswapV3Wrapper;
    ERC1155UniswapV3ConfigurationProvider configurationProvider;

    IPool pool;

    UniswapV3Testing.Data uniswapV3;

    constructor() {
        vm.createSelectFork("mainnet");
        vm.rollFork(18630167);

        uniswapV3.init(INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88));

        vm.startPrank(ADMIN);

        uniswapV3Wrapper = ERC1155UniswapV3Wrapper(
            address(
                new TransparentUpgradeableProxy(address(new ERC1155UniswapV3Wrapper()), ADMIN, abi.encodeCall(ERC1155UniswapV3Wrapper.initialize, (uniswapV3.positionManger)))
            )
        );

        _addAndDealToken(usdc);
        _addAndDealToken(weth);
        _addAndDealToken(usdt);

        addressesProvider = new PoolAddressesProvider("YLDR", ADMIN);
        addressesProvider.setACLAdmin(ADMIN);

        aclManager = new ACLManager(addressesProvider);

        address[] memory assets = new address[](2);
        address[] memory sources = new address[](2);
        address[] memory erc1155Assets = new address[](1);
        address[] memory erc1155Sources = new address[](1);

        assets[0] = address(usdc);
        sources[0] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

        assets[1] = address(weth);
        sources[1] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

        erc1155Assets[0] = address(uniswapV3Wrapper);
        erc1155Sources[0] = address(new ERC1155UniswapV3Oracle(addressesProvider, uniswapV3Wrapper));

        oracle =
        new YLDROracle(addressesProvider, assets, sources, erc1155Assets, erc1155Sources, address(0), address(0), 10 ** 8);

        aclManager.addPoolAdmin(ADMIN);
        addressesProvider.setACLManager(address(aclManager));
        addressesProvider.setPoolImpl(address(new Pool(addressesProvider)));
        addressesProvider.setPoolConfiguratorImpl(address(new PoolConfigurator()));
        addressesProvider.setPriceOracle(address(oracle));

        pool = IPool(addressesProvider.getPool());

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

        configurationProvider = new ERC1155UniswapV3ConfigurationProvider(pool, uniswapV3Wrapper);

        ConfiguratorInputTypes.InitERC1155ReserveInput[] memory erc1155Reserves =
            new ConfiguratorInputTypes.InitERC1155ReserveInput[](1);
        erc1155Reserves[0] = ConfiguratorInputTypes.InitERC1155ReserveInput({
            nTokenImpl: address(new NToken()),
            underlyingAsset: address(uniswapV3Wrapper),
            treasury: ADMIN,
            configurationProvider: address(configurationProvider),
            params: ""
        });

        IPoolConfigurator(addressesProvider.getPoolConfigurator()).initERC1155Reserves(erc1155Reserves);

        vm.stopPrank();

        _approveAllTokensForAllCallers(address(pool));

        vm.startPrank(ALICE);
        uniswapV3Wrapper.setApprovalForAll(address(pool), true);

        vm.startPrank(BOB);
        uniswapV3Wrapper.setApprovalForAll(address(pool), true);

        vm.startPrank(CAROL);
        uniswapV3Wrapper.setApprovalForAll(address(pool), true);

        // Default prank is Alice
        vm.startPrank(ALICE);
    }

    function _acquireWrapperUniswapV3Position(
        address token0,
        address token1,
        uint256 amount0Max,
        uint256 amount1Max,
        UniswapV3Testing.PositionType posType
    ) internal returns (uint256 tokenId, uint256 amount0, uint256 amount1) {
        (tokenId, amount0, amount1) = uniswapV3.acquireUniswapPosition(token0, token1, amount0Max, amount1Max, posType);

        uniswapV3.positionManger.safeTransferFrom(ALICE, address(uniswapV3Wrapper), tokenId, "");
    }

    function test_position_value() public {
        (uint256 tokenId, uint256 amount0, uint256 amount1) = _acquireWrapperUniswapV3Position(
            address(usdc), address(weth), 1000e6, 1e18, UniswapV3Testing.PositionType.Both
        );

        uint256 usdcPrice = oracle.getAssetPrice(address(usdc));
        uint256 wethPrice = oracle.getAssetPrice(address(weth));

        // Approximate because oracle accounts for pool price deviation and this calculation does not
        uint256 approxValue =
            amount0 * usdcPrice / (10 ** usdc.decimals()) + amount1 * wethPrice / (10 ** weth.decimals());
        uint256 valueFromOracle = oracle.getERC1155AssetPrice(address(uniswapV3Wrapper), tokenId);

        assertApproxEqRel(valueFromOracle, approxValue, 1e16);
    }

    function test_partial_burn() public {
        (uint256 tokenId, uint256 amount0, uint256 amount1) = _acquireWrapperUniswapV3Position(
            address(usdc), address(weth), 1000e6, 1e18, UniswapV3Testing.PositionType.Both
        );

        uint256 balance = uniswapV3Wrapper.balanceOf(ALICE, tokenId);
        assertGt(balance, 0);

        (uint256 amount0First, uint256 amount1First) = uniswapV3Wrapper.burn(ALICE, tokenId, balance / 2, ALICE);
        (uint256 amount0Second, uint256 amount1Second) = uniswapV3Wrapper.burn(ALICE, tokenId, balance / 2, ALICE);

        // We may lose 1 wei on precision for each operation
        assertGe(amount0First + amount0Second + 2, amount0);
        assertGe(amount1First + amount1Second + 2, amount1);
    }

    function test_unwrap() public {
        (uint256 tokenId, uint256 amount0, uint256 amount1) = _acquireWrapperUniswapV3Position(
            address(usdc), address(weth), 1000e6, 1e18, UniswapV3Testing.PositionType.Both
        );

        uniswapV3Wrapper.unwrap(ALICE, tokenId, ALICE);

        assertEq(uniswapV3Wrapper.balanceOf(ALICE, tokenId), 0);
        assertEq(uniswapV3.positionManger.ownerOf(tokenId), ALICE);
    }

    function test_supply() public {
        (uint256 tokenId, uint256 amount0, uint256 amount1) = _acquireWrapperUniswapV3Position(
            address(usdc), address(weth), 1000e6, 1e18, UniswapV3Testing.PositionType.Both
        );

        pool.supplyERC1155(address(uniswapV3Wrapper), tokenId, uniswapV3Wrapper.balanceOf(ALICE, tokenId), ALICE, 0);

        (uint256 totalCollateralBase,,,,,) = pool.getUserAccountData(ALICE);

        assertGt(totalCollateralBase, 0);
    }

    function test_supply_reverts_if_unsupported() public {
        (uint256 tokenId, uint256 amount0, uint256 amount1) = _acquireWrapperUniswapV3Position(
            address(weth), address(usdt), 1e18, 1000e6, UniswapV3Testing.PositionType.Both
        );

        uint256 balance = uniswapV3Wrapper.balanceOf(ALICE, tokenId);
        vm.expectRevert(bytes(Errors.RESERVE_INACTIVE));
        pool.supplyERC1155(address(uniswapV3Wrapper), tokenId, balance, BOB, 0);
    }
}
