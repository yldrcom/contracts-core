// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {VersionedInitializable} from "../libraries/yldr-upgradeability/VersionedInitializable.sol";
import {ERC1155SupplyUpgradeable} from "../libraries/yldr-upgradeability/ERC1155SupplyUpgradeable.sol";
import {IPool} from "../../interfaces/IPool.sol";
import {Errors} from "../libraries/helpers/Errors.sol";
import {IERC1155} from "../../dependencies/openzeppelin/contracts/IERC1155.sol";
import {INToken} from "../../interfaces/INToken.sol";

/**
 * @title YLDR NToken
 *
 */
contract NToken is ERC1155SupplyUpgradeable, INToken {
    uint256 public constant NTOKEN_REVISION = 0x1;
    address private _underlyingAsset;
    IPool public pool;

    modifier onlyPool() {
        require(_msgSender() == address(pool), Errors.CALLER_MUST_BE_POOL);
        _;
    }

    /// @inheritdoc VersionedInitializable
    function getRevision() internal pure virtual override returns (uint256) {
        return NTOKEN_REVISION;
    }

    /// @inheritdoc INToken
    function initialize(address _pool, address underlyingAsset, bytes memory params)
        public
        virtual
        override
        initializer
    {
        __ERC1155_init("");
        _underlyingAsset = underlyingAsset;

        pool = IPool(_pool);

        emit Initialized(address(underlyingAsset), address(pool), params);
    }

    /// @inheritdoc INToken
    function mint(address caller, address onBehalfOf, uint256 underlyingTokenId, uint256 amount)
        external
        virtual
        override
        onlyPool
        returns (bool)
    {
        // This may cause problems with underlying tokens which may same tokenId several times
        _mint(onBehalfOf, underlyingTokenId, amount, bytes(""));

        return (balanceOf(caller, underlyingTokenId) == amount);
    }

    /// @inheritdoc INToken
    function burn(address from, address receiverOfUnderlying, uint256 tokenId, uint256 amount)
        external
        virtual
        override
        onlyPool
    {
        _burn(from, tokenId, amount);
        if (receiverOfUnderlying != address(this)) {
            IERC1155(_underlyingAsset).safeTransferFrom(address(this), receiverOfUnderlying, tokenId, amount, bytes(""));
        }
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        virtual
        override
    {
        super._update(from, to, ids, values);

        if (to == address(0) || from == address(0)) {
            // Mints and burns are always authorized
            return;
        }

        pool.finalizeERC1155Transfer(_underlyingAsset, from, to, ids, values);
    }

    /// @inheritdoc INToken
    function UNDERLYING_ASSET_ADDRESS() external view override returns (address) {
        return _underlyingAsset;
    }
}
