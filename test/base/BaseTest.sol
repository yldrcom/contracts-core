pragma solidity ^0.8.20;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BaseTest is Test {
    using SafeERC20 for IERC20Metadata;

    address ADMIN;
    address ALICE;
    address BOB;
    address CAROL;

    address[] callers;
    IERC20Metadata[] tokens;

    constructor() {
        callers.push(ADMIN = vm.addr(0xad1119));
        callers.push(ALICE = vm.addr(0xa111ce));
        callers.push(BOB = vm.addr(0xb0b));
        callers.push(CAROL = vm.addr(0xca10c));

        vm.label(ADMIN, "ADMIN");
        vm.label(ALICE, "ALICE");
        vm.label(BOB, "BOB");
        vm.label(CAROL, "CAROL");
    }

    modifier recoverPrankIfAny() {
        (VmSafe.CallerMode mode, address sender,) = vm.readCallers();
        bool willNeedRecovery = mode == VmSafe.CallerMode.RecurrentPrank;
        vm.stopPrank();
        _;
        if (willNeedRecovery) {
            vm.startPrank(sender);
        }
    }

    function _addAndDealToken(IERC20Metadata token) internal {
        vm.label(address(token), token.symbol());
        tokens.push(token);

        for (uint256 i = 0; i < callers.length; i++) {
            deal(address(token), callers[i], 1_000_000_000 * (10 ** token.decimals()));
        }
    }

    function _approveAllTokensForAllCallers(address spender) internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            _approveTokenForAllCallers(tokens[i], spender);
        }
    }

    function _approveTokenForAllCallers(IERC20Metadata token, address spender) internal recoverPrankIfAny {
        for (uint256 i = 0; i < callers.length; i++) {
            vm.startPrank(callers[i]);
            token.forceApprove(spender, type(uint256).max);
            vm.stopPrank();
        }
    }
}
