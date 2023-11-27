pragma solidity ^0.8.20;

import {IERC1155PriceOracle} from "src/interfaces/IERC1155PriceOracle.sol";

contract ERC1155PriceOracleMock is IERC1155PriceOracle {
    mapping(uint256 => uint256) public getAssetPrice;

    function setAssetPrice(uint256 tokenId, uint256 price) external {
        getAssetPrice[tokenId] = price;
    }
}
