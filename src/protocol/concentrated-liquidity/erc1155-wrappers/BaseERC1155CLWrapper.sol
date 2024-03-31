// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {BaseCLAdapter} from "../adapters/BaseCLAdapter.sol";
import {ERC1155SupplyUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

abstract contract BaseERC1155CLWrapper is BaseCLAdapter, ERC1155SupplyUpgradeable, IERC721Receiver {
    error OnlyPositionManager();

    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (_msgSender() != _getPositionManager()) revert OnlyPositionManager();
        _mint(operator, tokenId, 10 ** 18, data);
        return IERC721Receiver.onERC721Received.selector;
    }

    function getPositionManager() public view returns (address) {
        return _getPositionManager();
    }

    function getPendingFees(uint256 tokenId) public view returns (uint256 amount0, uint256 amount1) {
        BaseCLAdapter.PositionData memory position = _getPositionData(tokenId);
        return _getPendingFees(position);
    }

    function getPositionData(uint256 tokenid) public view returns (PositionData memory) {
        return _getPositionData(tokenid);
    }

    function burn(address account, uint256 tokenId, uint256 value, address recipient)
        public
        returns (uint256 amount0, uint256 amount1)
    {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        uint256 _totalSupply = totalSupply(tokenId);

        _burn(account, tokenId, value);

        BaseCLAdapter.PositionData memory position = _getPositionData(tokenId);
        (uint256 fees0, uint256 fees1) = _getPendingFees(position);

        (amount0, amount1) =
            _decreaseLiquidity({tokenId: tokenId, liquidity: uint128(position.liquidity * value / _totalSupply)});

        amount0 += fees0 * value / _totalSupply;
        amount1 += fees1 * value / _totalSupply;

        return _collectFees(position.tokenId, uint128(amount0), uint128(amount1), recipient);
    }

    function unwrap(address account, uint256 tokenId, address recipient) public {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        _burn(account, tokenId, totalSupply(tokenId));

        IERC721(_getPositionManager()).safeTransferFrom(address(this), recipient, tokenId, "");
    }

    /// @inheritdoc ERC1155SupplyUpgradeable
    function totalSupply(uint256 id) public view override(ERC1155SupplyUpgradeable) returns (uint256) {
        return ERC1155SupplyUpgradeable.totalSupply(id);
    }

    /// @inheritdoc ERC1155SupplyUpgradeable
    function totalSupply() public view override(ERC1155SupplyUpgradeable) returns (uint256) {
        return ERC1155SupplyUpgradeable.totalSupply();
    }

    /// @inheritdoc ERC1155SupplyUpgradeable
    function exists(uint256 id) public view override(ERC1155SupplyUpgradeable) returns (bool) {
        return ERC1155SupplyUpgradeable.exists(id);
    }
}
