pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20Ownable} from "../src/mocks/ERC20Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPoolAddressesProvider} from "../src/interfaces/IPoolAddressesProvider.sol";
import {ACLManager} from "../src/protocol/configuration/ACLManager.sol";
import {PoolConfigurator} from "../src/protocol/pool/PoolConfigurator.sol";
import {Pool} from "../src/protocol/pool/Pool.sol";
import {IYLDROracle} from "../src/interfaces/IYLDROracle.sol";
import {IPoolConfigurator, ConfiguratorInputTypes} from "../src/interfaces/IPoolConfigurator.sol";
import {DefaultReserveInterestRateStrategy} from "../src/protocol/pool/DefaultReserveInterestRateStrategy.sol";
import {ERC1155UniswapV3Wrapper} from "../src/protocol/concentrated-liquidity/erc1155-wrappers/ERC1155UniswapV3Wrapper.sol";
import {ERC1155CLWrapperOracle} from "../src/protocol/concentrated-liquidity/ERC1155CLWrapperOracle.sol";
import {ERC1155CLWrapperConfigurationProvider} from
    "../src/protocol/concentrated-liquidity/ERC1155CLWrapperConfigurationProvider.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IPool} from "../src/interfaces/IPool.sol";

contract ConfigScript is Script {
    struct InitReserveArgs {
        IPoolAddressesProvider provider;
        IERC20Metadata underlying;
        address interestRateStrategy;
        address yTokenImpl;
        address variableDebtImpl;
        address priceFeed;
        uint256 ltv;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 reserveFactor;
        uint256 liquidationProtocolFee;
    }
    // initReserve((address,address,address,address,address,address,uint256,uint256,uint256,uint256,uint256))

    function initReserve(InitReserveArgs memory params) public {
        vm.startBroadcast();

        IPoolConfigurator configurator = IPoolConfigurator(params.provider.getPoolConfigurator());
        IYLDROracle oracle = IYLDROracle(params.provider.getPriceOracle());

        address[] memory assets = new address[](1);
        assets[0] = address(params.underlying);
        address[] memory sources = new address[](1);
        sources[0] = params.priceFeed;

        oracle.setAssetSources(assets, sources);

        (, address deployer,) = vm.readCallers();

        ConfiguratorInputTypes.InitReserveInput[] memory reserves = new ConfiguratorInputTypes.InitReserveInput[](1);
        reserves[0] = ConfiguratorInputTypes.InitReserveInput({
            yTokenImpl: params.yTokenImpl,
            variableDebtTokenImpl: params.variableDebtImpl,
            underlyingAssetDecimals: params.underlying.decimals(),
            interestRateStrategyAddress: params.interestRateStrategy,
            underlyingAsset: address(params.underlying),
            treasury: deployer,
            incentivesController: address(0),
            yTokenName: string.concat("YLDR Interest bearing ", params.underlying.symbol()),
            yTokenSymbol: string.concat("y", params.underlying.symbol()),
            variableDebtTokenName: string.concat("YLDR Variable Debt ", params.underlying.symbol()),
            variableDebtTokenSymbol: string.concat("v", params.underlying.symbol()),
            params: ""
        });

        configurator.initReserves(reserves);
        configurator.setReserveBorrowing(address(params.underlying), true);
        configurator.setReserveFactor(address(params.underlying), params.reserveFactor);
        configurator.setReserveFlashLoaning(address(params.underlying), true);
        configurator.setLiquidationProtocolFee(address(params.underlying), params.liquidationProtocolFee);

        configurator.configureReserveAsCollateral(
            address(params.underlying), params.ltv, params.liquidationThreshold, params.liquidationBonus
        );
    }

    function deployAndInitUniswapV3(
        IPoolAddressesProvider provider,
        INonfungiblePositionManager positionManager,
        address nTokenImpl
    ) public {
        vm.startBroadcast();

        (, address deployer,) = vm.readCallers();

        ERC1155UniswapV3Wrapper wrapper = ERC1155UniswapV3Wrapper(
            address(
                new TransparentUpgradeableProxy(
                    address(new ERC1155UniswapV3Wrapper(address(positionManager))),
                    deployer,
                    abi.encodeCall(ERC1155UniswapV3Wrapper.initialize, ())
                )
            )
        );
        ERC1155CLWrapperOracle oracle = new ERC1155CLWrapperOracle(provider, wrapper);
        ERC1155CLWrapperConfigurationProvider configProvider =
            new ERC1155CLWrapperConfigurationProvider(IPool(provider.getPool()), wrapper);

        ConfiguratorInputTypes.InitERC1155ReserveInput[] memory erc1155Reserves =
            new ConfiguratorInputTypes.InitERC1155ReserveInput[](1);
        erc1155Reserves[0] = ConfiguratorInputTypes.InitERC1155ReserveInput({
            nTokenImpl: nTokenImpl,
            underlyingAsset: address(wrapper),
            treasury: deployer,
            configurationProvider: address(configProvider),
            params: ""
        });
        PoolConfigurator(provider.getPoolConfigurator()).initERC1155Reserves(erc1155Reserves);

        address[] memory assets = new address[](1);
        assets[0] = address(wrapper);
        address[] memory sources = new address[](1);
        sources[0] = address(oracle);
        IYLDROracle(provider.getPriceOracle()).setERC1155AssetSources(assets, sources);
    }
}
