// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @dev Obtained via `cast interface 0x1a3c9B1d2F0529D97f2afC5136Cc23e58f1FD35B --chain arbitrum`
interface IAlgebraFactory {
    event DefaultCommunityFee(uint8 newDefaultCommunityFee);
    event FarmingAddress(address indexed newFarmingAddress);
    event FeeConfiguration(
        uint16 alpha1,
        uint16 alpha2,
        uint32 beta1,
        uint32 beta2,
        uint16 gamma1,
        uint16 gamma2,
        uint32 volumeBeta,
        uint16 volumeGamma,
        uint16 baseFee
    );
    event Owner(address indexed newOwner);
    event Pool(address indexed token0, address indexed token1, address pool);
    event VaultAddress(address indexed newVaultAddress);

    function baseFeeConfiguration()
        external
        view
        returns (
            uint16 alpha1,
            uint16 alpha2,
            uint32 beta1,
            uint32 beta2,
            uint16 gamma1,
            uint16 gamma2,
            uint32 volumeBeta,
            uint16 volumeGamma,
            uint16 baseFee
        );
    function createPool(address tokenA, address tokenB) external returns (address pool);
    function defaultCommunityFee() external view returns (uint8);
    function farmingAddress() external view returns (address);
    function owner() external view returns (address);
    function poolByPair(address, address) external view returns (address);
    function poolDeployer() external view returns (address);
    function setBaseFeeConfiguration(
        uint16 alpha1,
        uint16 alpha2,
        uint32 beta1,
        uint32 beta2,
        uint16 gamma1,
        uint16 gamma2,
        uint32 volumeBeta,
        uint16 volumeGamma,
        uint16 baseFee
    ) external;
    function setDefaultCommunityFee(uint8 newDefaultCommunityFee) external;
    function setFarmingAddress(address _farmingAddress) external;
    function setOwner(address _owner) external;
    function setVaultAddress(address _vaultAddress) external;
    function vaultAddress() external view returns (address);
}
