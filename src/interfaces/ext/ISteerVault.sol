// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ISteerVault {
    struct LiquidityPositions {
        int24[] lowerTick;
        int24[] upperTick;
        uint16[] relativeWeight;
    }

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function STEER_FRACTION_OF_FEE() external view returns (uint256);
    function TOTAL_FEE() external view returns (uint256);
    function accruedSteerFees0() external view returns (uint256);
    function accruedSteerFees1() external view returns (uint256);
    function accruedStrategistFees0() external view returns (uint256);
    function accruedStrategistFees1() external view returns (uint256);
    function algebraMintCallback(uint256 amount0, uint256 amount1, bytes memory) external;
    function algebraSwapCallback(int256 amount0Wanted, int256 amount1Wanted, bytes memory) external;
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function deposit(uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min, address to)
        external
        returns (uint256 shares, uint256 amount0Used, uint256 amount1Used);
    function emergencyBurn(int24 tickLower, int24 tickUpper, uint128 liquidity)
        external
        returns (uint256 amount0, uint256 amount1);
    function getPositions()
        external
        view
        returns (int24[] memory lowerTick, int24[] memory upperTick, uint16[] memory relativeWeight);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function getTotalAmounts() external view returns (uint256 total0, uint256 total1);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function initialize(address _vaultManager, address, address _steer, bytes memory _params) external;
    function maxTickChange() external view returns (int24);
    function name() external view returns (string memory);
    function pause() external;
    function paused() external view returns (bool);
    function poke() external;
    function pool() external view returns (address);
    function renounceRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function steerCollectFees(uint256 amount0, uint256 amount1, address to) external;
    function strategistCollectFees(uint256 amount0, uint256 amount1, address to) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function tend(uint256 totalWeight, LiquidityPositions memory newPositions, bytes memory timeSensitiveData)
        external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function twapInterval() external view returns (uint32);
    function unpause() external;
    function withdraw(uint256 shares, uint256 amount0Min, uint256 amount1Min, address to)
        external
        returns (uint256 amount0, uint256 amount1);
}
