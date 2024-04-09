pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolAddressesProvider} from "../src/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {IPoolDataProvider} from "../src/interfaces/IPoolDataProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OperationsScript is Script {
    function _getAllTokens(IPoolAddressesProvider addressesProvider) public view returns (address[] memory tokens) {
        IPoolDataProvider dataProvider = IPoolDataProvider(addressesProvider.getPoolDataProvider());
        IPoolDataProvider.TokenData[] memory tokenDatas = dataProvider.getAllReservesTokens();

        tokens = new address[](tokenDatas.length);

        for (uint256 i = 0; i < tokenDatas.length; i++) {
            tokens[i] = tokenDatas[i].tokenAddress;
        }
    }

    function collectFees(IPoolAddressesProvider addressesProvider) public {
        IPool pool = IPool(addressesProvider.getPool());
        address[] memory tokens = _getAllTokens(addressesProvider);

        vm.startBroadcast();
        pool.mintToTreasury(tokens);
    }

    function countBalances(IPoolAddressesProvider addressesProvider, address user) public view {
        IPool pool = IPool(addressesProvider.getPool());
        address[] memory tokens = _getAllTokens(addressesProvider);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = IERC20(pool.getReserveData(tokens[i]).yTokenAddress).balanceOf(user);
            console2.log(tokens[i], balance);
        }
    }
}
