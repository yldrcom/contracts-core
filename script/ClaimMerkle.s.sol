pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolAddressesProvider} from "../src/interfaces/IPoolAddressesProvider.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {IACLManager} from "../src/interfaces/IACLManager.sol";
import {IPoolDataProvider} from "../src/interfaces/IPoolDataProvider.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155CLWrapper} from "../src/protocol/concentrated-liquidity/ERC1155CLWrapper.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {JsonBindings} from "./JsonBindings.sol";

struct MerkleClaimArgs {
    address[] users;
    address[] tokens;
    uint256[] amounts;
    bytes32[][] proofs;
}

contract ClaimMerkleScript is Script {
    using JsonBindings for string;

    function run(ERC1155CLWrapper wrapper, string memory jsonArgs) public {
        MerkleClaimArgs memory args = jsonArgs.deserializeMerkleClaimArgs();

        vm.broadcast();
        wrapper.claimMerkle(args.users, args.tokens, args.amounts, args.proofs);
    }
}
