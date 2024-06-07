// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IMerkleDistributor {
    struct MerkleTree {
        bytes32 merkleRoot;
        bytes32 ipfsHash;
    }

    error InvalidDispute();
    error InvalidLengths();
    error InvalidProof();
    error InvalidUninitializedRoot();
    error NoDispute();
    error NotGovernor();
    error NotTrusted();
    error NotWhitelisted();
    error UnresolvedDispute();
    error ZeroAddress();

    event AdminChanged(address previousAdmin, address newAdmin);
    event BeaconUpgraded(address indexed beacon);
    event Claimed(address indexed user, address indexed token, uint256 amount);
    event DisputeAmountUpdated(uint256 _disputeAmount);
    event DisputePeriodUpdated(uint48 _disputePeriod);
    event DisputeResolved(bool valid);
    event DisputeTokenUpdated(address indexed _disputeToken);
    event Disputed(string reason);
    event Initialized(uint8 version);
    event OperatorClaimingToggled(address indexed user, bool isEnabled);
    event OperatorToggled(address indexed user, address indexed operator, bool isWhitelisted);
    event Recovered(address indexed token, address indexed to, uint256 amount);
    event Revoked();
    event TreeUpdated(bytes32 merkleRoot, bytes32 ipfsHash, uint48 endOfDisputePeriod);
    event TrustedToggled(address indexed eoa, bool trust);
    event Upgraded(address indexed implementation);

    function canUpdateMerkleRoot(address) external view returns (uint256);
    function claim(address[] memory users, address[] memory tokens, uint256[] memory amounts, bytes32[][] memory proofs)
        external;
    function claimed(address, address) external view returns (uint208 amount, uint48 timestamp, bytes32 merkleRoot);
    function core() external view returns (address);
    function disputeAmount() external view returns (uint256);
    function disputePeriod() external view returns (uint48);
    function disputeToken() external view returns (address);
    function disputeTree(string memory reason) external;
    function disputer() external view returns (address);
    function endOfDisputePeriod() external view returns (uint48);
    function getMerkleRoot() external view returns (bytes32);
    function initialize(address _core) external;
    function lastTree() external view returns (bytes32 merkleRoot, bytes32 ipfsHash);
    function onlyOperatorCanClaim(address) external view returns (uint256);
    function operators(address, address) external view returns (uint256);
    function proxiableUUID() external view returns (bytes32);
    function recoverERC20(address tokenAddress, address to, uint256 amountToRecover) external;
    function resolveDispute(bool valid) external;
    function revokeTree() external;
    function setDisputeAmount(uint256 _disputeAmount) external;
    function setDisputePeriod(uint48 _disputePeriod) external;
    function setDisputeToken(address _disputeToken) external;
    function toggleOnlyOperatorCanClaim(address user) external;
    function toggleOperator(address user, address operator) external;
    function toggleTrusted(address eoa) external;
    function tree() external view returns (bytes32 merkleRoot, bytes32 ipfsHash);
    function updateTree(MerkleTree memory _tree) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}
