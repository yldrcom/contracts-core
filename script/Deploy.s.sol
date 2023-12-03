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

contract DeployScript is Script {
    function protocol() public {
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
    }
}
