// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/// @notice Gamma UniProxy
interface IUniProxy {
    function clearance() external view returns (address);
    function deposit(uint256 deposit0, uint256 deposit1, address to, address pos, uint256[4] memory minIn)
        external
        returns (uint256 shares);
    function getDepositAmount(address pos, address token, uint256 _deposit)
        external
        view
        returns (uint256 amountStart, uint256 amountEnd);
    function owner() external view returns (address);
    function transferClearance(address newClearance) external;
    function transferOwnership(address newOwner) external;
}
