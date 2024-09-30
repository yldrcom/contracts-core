// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {BaseCLAdapter} from "./adapters/BaseCLAdapter.sol";
import {ERC1155SupplyUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {CLAdapterWrapper} from "./CLAdapterWrapper.sol";
import {IMerkleDistributor} from "../../interfaces/ext/IMerkleDistributor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC1155CLWrapper is ERC1155SupplyUpgradeable, IERC721Receiver {
    using CLAdapterWrapper for BaseCLAdapter;
    using SafeERC20 for IERC20;

    BaseCLAdapter public immutable adapter;
    IMerkleDistributor public immutable distributor;
    address public immutable rewardsRecipient;

    constructor(BaseCLAdapter _adapter, IMerkleDistributor _distributor, address _rewardsRecipient) {
        adapter = _adapter;
        distributor = _distributor;
        rewardsRecipient = _rewardsRecipient;

        _disableInitializers();
    }

    function initialize() public reinitializer(4) {
        __ERC1155_init("");
    }

    error OnlyPositionManager();

    function onERC721Received(address operator, address, uint256 tokenId, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (_msgSender() != adapter.getPositionManager()) revert OnlyPositionManager();
        _mint(operator, tokenId, 10 ** 18, data);
        return IERC721Receiver.onERC721Received.selector;
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

        BaseCLAdapter.PositionData memory position = adapter.getPositionData(tokenId);
        (uint256 fees0, uint256 fees1) = adapter.getPendingFees(position);

        (amount0, amount1) = adapter.delegateDecreaseLiquidity({
            tokenId: tokenId,
            liquidity: uint128(position.liquidity * value / _totalSupply)
        });

        amount0 += fees0 * value / _totalSupply;
        amount1 += fees1 * value / _totalSupply;

        return adapter.delegateCollectFees(position.tokenId, uint128(amount0), uint128(amount1), recipient);
    }

    function unwrap(address account, uint256 tokenId, address recipient) public {
        if (account != _msgSender() && !isApprovedForAll(account, _msgSender())) {
            revert ERC1155MissingApprovalForAll(_msgSender(), account);
        }

        _burn(account, tokenId, totalSupply(tokenId));

        IERC721(adapter.getPositionManager()).safeTransferFrom(address(this), recipient, tokenId, "");
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

    function claimMerkle(
        address[] memory users,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes32[][] memory proofs
    ) external {
        distributor.claim(users, tokens, amounts, proofs);
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(rewardsRecipient, amounts[i]);
        }
    }

    function withdrawTokens(address[] memory tokens) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(rewardsRecipient, IERC20(tokens[i]).balanceOf(address(this)));
        }
    }
}
