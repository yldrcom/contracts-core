pragma solidity ^0.8.20;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Ownable is ERC20Permit, Ownable {
    uint8 private _decimals;

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    constructor(string memory name, string memory symbol, uint8 decimals_)
        ERC20(name, symbol)
        ERC20Permit(name)
        Ownable(msg.sender)
    {
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
