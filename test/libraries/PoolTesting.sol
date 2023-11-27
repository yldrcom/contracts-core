pragma solidity 0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {IPoolConfigurator, ConfiguratorInputTypes} from "../../src/interfaces/IPoolConfigurator.sol";
import {Pool} from "../../src/protocol/pool/Pool.sol";
import {IPool} from "../../src/interfaces/IPool.sol";
import {PoolAddressesProvider} from "../../src/protocol/configuration/PoolAddressesProvider.sol";
import {PoolConfigurator} from "../../src/protocol/pool/PoolConfigurator.sol";
import {ACLManager} from "../../src/protocol/configuration/ACLManager.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";
import {ERC1155Mock} from "../../src/mocks/ERC1155Mock.sol";
import {ERC1155ConfigurationProviderMock} from "../../src/mocks/ERC1155ConfigurationProviderMock.sol";
import {YToken} from "../../src/protocol/tokenization/YToken.sol";
import {NToken} from "../../src/protocol/tokenization/NToken.sol";
import {VariableDebtToken} from "../../src/protocol/tokenization/VariableDebtToken.sol";
import {DefaultReserveInterestRateStrategy} from "../../src/protocol/pool/DefaultReserveInterestRateStrategy.sol";
import {YLDROracle} from "../../src/misc/YLDROracle.sol";
import {Errors} from "../../src/protocol/libraries/helpers/Errors.sol";
import {DataTypes} from "../../src/protocol/libraries/types/DataTypes.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library PoolTesting {
    struct Data {
        address admin;
        PoolAddressesProvider addressesProvider;
        address yTokenImpl;
        address nTokenImpl;
        address variableDebtTokenImpl;
    }

    function init(Data storage self, address admin) internal {
        self.admin = admin;
        self.addressesProvider = new PoolAddressesProvider("YLDR", admin);
        self.addressesProvider.setACLAdmin(admin);

        ACLManager aclManager = new ACLManager(self.addressesProvider);
        YLDROracle oracle = new YLDROracle(
            self.addressesProvider,
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            address(0),
            address(0),
            10 ** 8
        );

        aclManager.addPoolAdmin(admin);
        self.addressesProvider.setACLManager(address(aclManager));
        self.addressesProvider.setPoolImpl(address(new Pool(self.addressesProvider)));
        self.addressesProvider.setPoolConfiguratorImpl(address(new PoolConfigurator()));
        self.addressesProvider.setPriceOracle(address(oracle));

        self.yTokenImpl = address(new YToken(Pool(self.addressesProvider.getPool())));
        self.nTokenImpl = address(new NToken());
        self.variableDebtTokenImpl = address(new VariableDebtToken(Pool(self.addressesProvider.getPool())));
    }

    function addReserve(
        Data storage self,
        address asset,
        uint256 optimalUsageRatio,
        uint256 baseVariableBorrowRate,
        uint256 variableRateSlope1,
        uint256 variableRateSlope2,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus,
        address priceSource
    ) internal {
        ConfiguratorInputTypes.InitReserveInput[] memory reserves = new ConfiguratorInputTypes.InitReserveInput[](1);
        reserves[0] = ConfiguratorInputTypes.InitReserveInput({
            yTokenImpl: self.yTokenImpl,
            variableDebtTokenImpl: self.variableDebtTokenImpl,
            underlyingAssetDecimals: IERC20Metadata(asset).decimals(),
            interestRateStrategyAddress: address(
                new DefaultReserveInterestRateStrategy(
                    self.addressesProvider,
                    optimalUsageRatio,
                    baseVariableBorrowRate,
                    variableRateSlope1,
                    variableRateSlope2
                )
                ),
            underlyingAsset: asset,
            treasury: self.admin,
            incentivesController: address(0),
            yTokenName: string.concat("YLDR Interest bearing ", IERC20Metadata(asset).symbol()),
            yTokenSymbol: string.concat("y", IERC20Metadata(asset).symbol()),
            variableDebtTokenName: string.concat("YLDR Variable Debt ", IERC20Metadata(asset).symbol()),
            variableDebtTokenSymbol: string.concat("v", IERC20Metadata(asset).symbol()),
            params: ""
        });

        PoolConfigurator(self.addressesProvider.getPoolConfigurator()).initReserves(reserves);
        PoolConfigurator(self.addressesProvider.getPoolConfigurator()).setReserveBorrowing(asset, true);
        PoolConfigurator(self.addressesProvider.getPoolConfigurator()).configureReserveAsCollateral(
            asset, ltv, liquidationThreshold, liquidationBonus
        );

        address[] memory assets = new address[](1);
        assets[0] = asset;
        address[] memory sources = new address[](1);
        sources[0] = priceSource;
        YLDROracle(self.addressesProvider.getPriceOracle()).setAssetSources(assets, sources);
    }

    function addERC1155Reserve(Data storage self, address asset, address configurationProvider, address priceSource)
        internal
    {
        ConfiguratorInputTypes.InitERC1155ReserveInput[] memory erc1155Reserves =
            new ConfiguratorInputTypes.InitERC1155ReserveInput[](1);
        erc1155Reserves[0] = ConfiguratorInputTypes.InitERC1155ReserveInput({
            nTokenImpl: address(new NToken()),
            underlyingAsset: asset,
            treasury: self.admin,
            configurationProvider: configurationProvider,
            params: ""
        });
        PoolConfigurator(self.addressesProvider.getPoolConfigurator()).initERC1155Reserves(erc1155Reserves);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        address[] memory sources = new address[](1);
        sources[0] = priceSource;
        YLDROracle(self.addressesProvider.getPriceOracle()).setERC1155AssetSources(assets, sources);
    }
}
