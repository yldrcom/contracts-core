// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {ERC1155SupplyUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IERC1155UniswapV3Wrapper is IERC721Receiver {
    error OnlyPositionManager();

    function positionManager() external view returns (INonfungiblePositionManager);

    function factory() external view returns (IUniswapV3Factory);

    function initialize(INonfungiblePositionManager _positionManager) external;

    function getPendingFees(uint256 tokenId) external view returns (uint256 amount0, uint256 amount1);

    function burn(address account, uint256 tokenId, uint256 value, address recipient)
        external
        returns (uint256 amount0, uint256 amount1);

    function unwrap(address account, uint256 tokenId, address recipient) external;
}
