pragma solidity 0.8.23;

import {Vm} from "forge-std/Vm.sol";

library Utils {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function getCurrentCaller() internal returns (address caller) {
        (, caller,) = vm.readCallers();
    }
}
