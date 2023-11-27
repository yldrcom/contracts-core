// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IERC1155ConfigurationProvider} from "../interfaces/IERC1155ConfigurationProvider.sol";
import {DataTypes} from "../protocol/libraries/types/DataTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ERC1155ConfigurationProviderMock is Ownable, IERC1155ConfigurationProvider {
    constructor() Ownable(msg.sender) {}

    mapping(uint256 tokenId => DataTypes.ERC1155ReserveConfiguration) public reserveConfigs;

    function getERC1155ReserveConfig(uint256 tokenId)
        external
        view
        returns (DataTypes.ERC1155ReserveConfiguration memory)
    {
        return reserveConfigs[tokenId];
    }

    function setERC1155ReserveConfig(uint256 tokenId, DataTypes.ERC1155ReserveConfiguration memory config)
        external
        onlyOwner
    {
        reserveConfigs[tokenId] = config;
    }
}
