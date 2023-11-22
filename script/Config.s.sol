pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20Ownable} from "src/mocks/ERC20Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPoolAddressesProvider} from "src/interfaces/IPoolAddressesProvider.sol";
import {ACLManager} from "src/protocol/configuration/ACLManager.sol";
import {PoolConfigurator} from "src/protocol/pool/PoolConfigurator.sol";
import {Pool} from "src/protocol/pool/Pool.sol";
import {IYLDROracle} from "src/interfaces/IYLDROracle.sol";
import {IPoolConfigurator, ConfiguratorInputTypes} from "src/interfaces/IPoolConfigurator.sol";
import {DefaultReserveInterestRateStrategy} from "src/protocol/pool/DefaultReserveInterestRateStrategy.sol";

contract ConfigScript is Script {
    function initReserve(
        IPoolAddressesProvider provider,
        IERC20Metadata underlying,
        address yTokenImpl,
        address variableDebtImpl,
        address priceFeed,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    ) public {
        vm.startBroadcast();

        IPoolConfigurator configurator = IPoolConfigurator(provider.getPoolConfigurator());
        IYLDROracle oracle = IYLDROracle(provider.getPriceOracle());

        address[] memory assets = new address[](1);
        assets[0] = address(underlying);
        address[] memory sources = new address[](1);
        sources[0] = priceFeed;

        oracle.setAssetSources(assets, sources);

        (, address deployer,) = vm.readCallers();

        ConfiguratorInputTypes.InitReserveInput[] memory reserves = new ConfiguratorInputTypes.InitReserveInput[](1);
        reserves[0] = ConfiguratorInputTypes.InitReserveInput({
            yTokenImpl: yTokenImpl,
            variableDebtTokenImpl: variableDebtImpl,
            underlyingAssetDecimals: underlying.decimals(),
            interestRateStrategyAddress: address(
                new DefaultReserveInterestRateStrategy(provider, 0.8e27, 0, 0.02e27, 0.8e27)
                ),
            underlyingAsset: address(underlying),
            treasury: deployer,
            incentivesController: address(0),
            yTokenName: string.concat("YLDR Interest bearing ", underlying.symbol()),
            yTokenSymbol: string.concat("y", underlying.symbol()),
            variableDebtTokenName: string.concat("YLDR Variable Debt ", underlying.symbol()),
            variableDebtTokenSymbol: string.concat("v", underlying.symbol()),
            params: ""
        });

        configurator.initReserves(reserves);
        configurator.setReserveBorrowing(address(underlying), true);

        configurator.configureReserveAsCollateral(address(underlying), ltv, liquidationThreshold, liquidationBonus);
    }
}
