pragma solidity ^0.8.20;

import {IPriceOracleGetter} from "src/interfaces/IPriceOracleGetter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract YLDROracleMock is Ownable, IPriceOracleGetter {
    mapping(address asset => uint256 price) public assetPrices;
    mapping(address erc1155Asset => mapping(uint256 tokenId => uint256)) public assetPricesById;

    constructor() Ownable(msg.sender) {}

    function BASE_CURRENCY() external pure returns (address) {
        return address(0);
    }

    function BASE_CURRENCY_UNIT() external pure returns (uint256) {
        return 1e8;
    }

    function getAssetPrice(address asset) external view override returns (uint256) {
        return assetPrices[asset];
    }

    function getERC1155AssetPrice(address asset, uint256 tokenId) external view returns (uint256) {
        return assetPricesById[asset][tokenId];
    }

    function setAssetPrice(address asset, uint256 price) external onlyOwner {
        assetPrices[asset] = price;
    }

    function setERC1155AssetPrice(address asset, uint256 tokenId, uint256 price) external onlyOwner {
        assetPricesById[asset][tokenId] = price;
    }
}
