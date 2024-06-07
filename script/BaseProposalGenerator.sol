pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

contract BaseProposalGenerator is Script {
    MultiSigCall[] public calls;

    struct MultiSigCall {
        address target;
        bytes data;
    }

    function _simulateAndPrintCalls(address multisig) public {
        vm.startPrank(multisig);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success,) = address(calls[i].target).call(calls[i].data);
            require(success);
            console.log(calls[i].target, vm.toString(calls[i].data));
        }

        delete calls;
    }
}
