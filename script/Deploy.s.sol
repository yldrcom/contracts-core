pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20Ownable} from "../src/mocks/ERC20Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PoolAddressesProvider} from "../src/protocol/configuration/PoolAddressesProvider.sol";
import {ACLManager} from "../src/protocol/configuration/ACLManager.sol";
import {PoolConfigurator} from "../src/protocol/pool/PoolConfigurator.sol";
import {Pool} from "../src/protocol/pool/Pool.sol";
import {YLDROracle} from "../src/misc/YLDROracle.sol";
import {IPoolConfigurator, ConfiguratorInputTypes} from "../src/interfaces/IPoolConfigurator.sol";
import {DefaultReserveInterestRateStrategy} from "../src/protocol/pool/DefaultReserveInterestRateStrategy.sol";
import {YLDRProtocolDataProvider} from "../src/misc/YLDRProtocolDataProvider.sol";
import {YToken} from "../src/protocol/tokenization/YToken.sol";
import {VariableDebtToken} from "../src/protocol/tokenization/VariableDebtToken.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {BaseProposalGenerator} from "./BaseProposalGenerator.sol";

contract DeployScript is Script {
    function pool(address addressesProvider) public {
        vm.startBroadcast();
        (, address deployer,) = vm.readCallers();

        Pool _pool = new Pool(PoolAddressesProvider(addressesProvider));

        console2.log("Pool:", address(_pool));
    }

    function protocol(uint256 maxERC1155Reserves, uint256 flashloanFee) public {
        vm.startBroadcast();

        (, address deployer,) = vm.readCallers();

        PoolAddressesProvider addressesProvider = new PoolAddressesProvider("YLDR", deployer);
        addressesProvider.setACLAdmin(deployer);
        ACLManager aclManager = new ACLManager(addressesProvider);
        YLDRProtocolDataProvider dataProvider = new YLDRProtocolDataProvider(addressesProvider);
        aclManager.addPoolAdmin(deployer);
        addressesProvider.setACLManager(address(aclManager));
        addressesProvider.setPoolImpl(address(new Pool(addressesProvider)));
        addressesProvider.setPoolConfiguratorImpl(address(new PoolConfigurator()));
        addressesProvider.setPoolDataProvider(address(dataProvider));

        IPoolConfigurator poolConfigurator = IPoolConfigurator(addressesProvider.getPoolConfigurator());

        YLDROracle oracle = new YLDROracle(
            addressesProvider,
            new address[](0),
            new address[](0),
            new address[](0),
            new address[](0),
            address(0),
            address(0),
            10 ** 8
        );
        addressesProvider.setPriceOracle(address(oracle));

        poolConfigurator.updateMaxERC1155CollateralReserves(maxERC1155Reserves);

        poolConfigurator.updateFlashloanPremiumTotal(uint128(flashloanFee));
        poolConfigurator.updateFlashloanPremiumToProtocol(1e4);

        YToken yTokenImpl = new YToken(IPool(addressesProvider.getPool()));
        VariableDebtToken variableDebtImpl = new VariableDebtToken(IPool(addressesProvider.getPool()));

        console2.log("PoolAddressesProvider:", address(addressesProvider));
        console2.log("Pool:", addressesProvider.getPool());
        console2.log("PoolConfigurator:", addressesProvider.getPoolConfigurator());
        console2.log("PoolDataProvider:", addressesProvider.getPoolDataProvider());
        console2.log("PriceOracle:", addressesProvider.getPriceOracle());
        console2.log("ACLManager:", addressesProvider.getACLManager());
    }
}

contract UpgradeConfigurator is BaseProposalGenerator {
    function run(PoolAddressesProvider addressesProvider) public {
        vm.startBroadcast();
        PoolConfigurator impl = new PoolConfigurator();

        calls.push(
            MultiSigCall({
                target: address(addressesProvider),
                data: abi.encodeCall(PoolAddressesProvider.setPoolConfiguratorImpl, (address(impl)))
            })
        );

        vm.stopBroadcast();
        _simulateAndPrintCalls(addressesProvider.owner());
    }
}
