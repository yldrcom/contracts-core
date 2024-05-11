pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolAddressesProvider} from "../src/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {IACLManager} from "../src/interfaces/IACLManager.sol";
import {IPoolDataProvider} from "../src/interfaces/IPoolDataProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseProposalGenerator} from "./BaseProposalGenerator.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract OperationsScript is BaseProposalGenerator {
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

    function collectFunds(IPoolAddressesProvider addressesProvider, address receiver) public {
        IPool pool = IPool(addressesProvider.getPool());
        address multisig = Ownable(address(addressesProvider)).owner();
        address[] memory tokens = _getAllTokens(addressesProvider);

        delete calls;

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = IERC20(pool.getReserveData(tokens[i]).yTokenAddress).balanceOf(multisig);
            if (balance > 0) {
                calls.push(
                    MultiSigCall({
                        target: address(pool),
                        data: abi.encodeCall(IPool.withdraw, (tokens[i], balance, multisig))
                    })
                );
            }
        }

        _simulateAndPrintCalls(multisig);
        delete calls;

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = IERC20(tokens[i]).balanceOf(multisig);
            if (balance > 0) {
                calls.push(
                    MultiSigCall({target: tokens[i], data: abi.encodeCall(IERC20.transfer, (receiver, balance))})
                );
            }
        }

        _simulateAndPrintCalls(multisig);
    }
}
