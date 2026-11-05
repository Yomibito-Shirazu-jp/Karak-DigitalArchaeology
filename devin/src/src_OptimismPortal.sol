// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { SafeCall } from "src/libraries/SafeCall.sol";
import { L2OutputOracle } from "src/L1/L2OutputOracle.sol";
import { SystemConfig } from "src/L1/SystemConfig.sol";
import { Constants } from "src/libraries/Constants.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Types } from "src/libraries/Types.sol";
import { Hashing } from "src/libraries/Hashing.sol";
import { SecureMerkleTrie } from "src/libraries/trie/SecureMerkleTrie.sol";
import { AddressAliasHelper } from "src/vendor/AddressAliasHelper.sol";
import { ResourceMetering } from "src/L1/ResourceMetering.sol";
import { ISemver } from "src/universal/ISemver.sol";
import { Constants } from "src/libraries/Constants.sol";

/// @custom:proxied
/// @title OptimismPortal
/// @notice The OptimismPortal is a low-level contract responsible for passing messages between L1
///         and L2. Messages sent directly to the OptimismPortal have no form of replayability.
///         Users are encouraged to use the L1CrossDomainMessenger for a higher-level interface.
contract OptimismPortal is Initializable, ResourceMetering, ISemver {
    /// @notice Represents a proven withdrawal.
    /// @custom:field outputRoot    Root of the L2 output this was proven against.
    /// @custom:field timestamp     Timestamp at whcih the withdrawal was proven.
    /// @custom:field l2OutputIndex Index of the output this was proven against.
    struct ProvenWithdrawal {
        bytes32 outputRoot;
        uint128 timestamp;
        uint128 l2OutputIndex;
    }

    /// @notice Version of the deposit event.
    uint256 internal constant DEPOSIT_VERSION = 0;

    /// @notice The L2 gas limit set when eth is deposited using the receive() function.
    uint64 internal constant RECEIVE_DEFAULT_GAS_LIMIT = 100_000;

    /// @notice Address of the L2 account which initiated a withdrawal in this transaction.
    ///         If the of this variable is the default L2 sender address, then we are NOT inside of
    ///         a call to finalizeWithdrawalTransaction.
    address public l2Sender;

    /// @notice A list of withdrawal hashes which have been successfully finalized.
    mapping(bytes32 => bool) public finalizedWithdrawals;

    /// @notice A mapping of withdrawal hashes to `ProvenWithdrawal` data.
    mapping(bytes32 => ProvenWithdrawal) public provenWithdrawals;

    /// @notice Determines if cross domain messaging is paused.
    ///         When set to true, withdrawals are paused.
    ///         This may be removed in the future.
    bool public paused;

    /// @notice Address of the L2OutputOracle contract.
    /// @custom:network-specific
    L2OutputOracle public l2Oracle;

    /// @notice Address of the SystemConfig contract.
    /// @custom:network-specific
    SystemConfig public systemConfig;

    /// @notice Address that has the ability to pause and unpause withdrawals.
    /// @custom:network-specific
    address public guardian;

    bytes32 public merkleRootETH;

    mapping(address => uint256) public claimedETH;

    uint256 public constant RECOVERY_TIMESTAMP = 1820707200;

    event MerkleRootETHSet(bytes32 indexed root, address indexed setter);
    event ETHClaimed(address indexed claimer, uint256 amount);
    event ETHRecovered(address indexed recipient, uint256 amount);

    /// @notice Emitted when a transaction is deposited from L1 to L2.
    ///         The parameters of this event are read by the rollup node and used to derive deposit
    ///         transactions on L2.
    /// @param from       Address that triggered the deposit transaction.
    /// @param to         Address that the deposit transaction is directed to.
    /// @param version    Version of this deposit transaction event.
    /// @param opaqueData ABI encoded deposit data to be parsed off-chain.
    event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData);

    /// @notice Emitted when a withdrawal transaction is proven.
    /// @param withdrawalHash Hash of the withdrawal transaction.
    /// @param from           Address that triggered the withdrawal transaction.
    /// @param to             Address that the withdrawal transaction is directed to.
    event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to);

    /// @notice Emitted when a withdrawal transaction is finalized.
    /// @param withdrawalHash Hash of the withdrawal transaction.
    /// @param success        Whether the withdrawal transaction was successful.
    event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success);

    /// @notice Emitted when the pause is triggered.
    /// @param account Address of the account triggering the pause.
    event Paused(address account);

    /// @notice Emitted when the pause is lifted.
    /// @param account Address of the account triggering the unpause.
    event Unpaused(address account);

    /// @notice Reverts when paused.
    modifier whenNotPaused() {
        require(paused == false, "OptimismPortal: paused");
        _;
    }

    /// @notice Semantic version.
    /// @custom:semver 1.10.0
    string public constant version = "2.3.0";

    /// @notice Constructs the OptimismPortal contract.
    constructor() {
        initialize({
            _l2Oracle: L2OutputOracle(address(0)),
            _guardian: address(0),
            _systemConfig: SystemConfig(address(0)),
            _paused: true
        });
    }

    /// @notice Initializer.
    /// @param _l2Oracle Address of the L2OutputOracle contract.
    /// @param _guardian Address that can pause withdrawals.
    /// @param _paused Sets the contract's pausability state.
    /// @param _systemConfig Address of the SystemConfig contract.
    function initialize(
        L2OutputOracle _l2Oracle,
        address _guardian,
        SystemConfig _systemConfig,
        bool _paused
    )
        public
        reinitializer(Constants.INITIALIZER)
    {
        l2Sender = Constants.DEFAULT_L2_SENDER;
        l2Oracle = _l2Oracle;
        systemConfig = _systemConfig;
        guardian = _guardian;
        paused = _paused;
        __ResourceMetering_init();
    }

    /// @notice Getter for the L2OutputOracle
    /// @custom:legacy
    function L2_ORACLE() external view returns (L2OutputOracle) {
        return l2Oracle;
    }

    /// @notice Getter for the SystemConfig
    /// @custom:legacy
    function SYSTEM_CONFIG() external view returns (SystemConfig) {
        return systemConfig;
    }

    /// @notice Getter for the Guardian
    /// @custom:legacy
    function GUARDIAN() external view returns (address) {
        return guardian;
    }

    /// @notice Pauses withdrawals.
    function pause() external {
        require(msg.sender == guardian, "OptimismPortal: only guardian can pause");
        paused = true;
        emit Paused(msg.sender);
    }

    /// @notice Unpauses withdrawals.
    function unpause() external {
        require(msg.sender == guardian, "OptimismPortal: only guardian can unpause");
        paused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Computes the minimum gas limit for a deposit.
    ///         The minimum gas limit linearly increases based on the size of the calldata.
    ///         This is to prevent users from creating L2 resource usage without paying for it.
    ///         This function can be used when interacting with the portal to ensure forwards
    ///         compatibility.
    /// @param _byteCount Number of bytes in the calldata.
    /// @return The minimum gas limit for a deposit.
    function minimumGasLimit(uint64 _byteCount) public pure returns (uint64) {
        return _byteCount * 16 + 21000;
    }

    /// @notice Accepts value so that users can send ETH directly to this contract and have the
    ///         funds be deposited to their address on L2. This is intended as a convenience
    ///         function for EOAs. Contracts should call the depositTransaction() function directly
    ///         otherwise any deposited funds will be lost due to address aliasing.
    // solhint-disable-next-line ordering
    receive() external payable {
        revert("OptimismPortal: deposits disabled");
    }

    /// @notice Accepts ETH value without triggering a deposit to L2.
    ///         This function mainly exists for the sake of the migration between the legacy
    ///         Optimism system and Bedrock.
    function donateETH() external payable {
        // Intentionally empty.
    }

    /// @notice Getter for the resource config.
    ///         Used internally by the ResourceMetering contract.
    ///         The SystemConfig is the source of truth for the resource config.
    /// @return ResourceMetering ResourceConfig
    function _resourceConfig() internal view override returns (ResourceMetering.ResourceConfig memory) {
        return systemConfig.resourceConfig();
    }

    /// @notice Proves a withdrawal transaction.
    /// @param _tx              Withdrawal transaction to finalize.
    /// @param _l2OutputIndex   L2 output index to prove against.
    /// @param _outputRootProof Inclusion proof of the L2ToL1MessagePasser contract's storage root.
    /// @param _withdrawalProof Inclusion proof of the withdrawal in L2ToL1MessagePasser contract.
    function proveWithdrawalTransaction(
        Types.WithdrawalTransaction memory _tx,
        uint256 _l2OutputIndex,
        Types.OutputRootProof calldata _outputRootProof,
        bytes[] calldata _withdrawalProof
    )
        external
    {
        revert("OptimismPortal: traditional withdrawal path disabled, use the new claim function");
    }

    /// @notice Finalizes a withdrawal transaction.
    /// @param _tx Withdrawal transaction to finalize.
    function finalizeWithdrawalTransaction(Types.WithdrawalTransaction memory _tx) external {
        revert("OptimismPortal: traditional withdrawal path disabled, use the new claim function");
    }

    /// @notice Accepts deposits of ETH and data, and emits a TransactionDeposited event for use in
    ///         deriving deposit transactions. Note that if a deposit is made by a contract, its
    ///         address will be aliased when retrieved using `tx.origin` or `msg.sender`. Consider
    ///         using the CrossDomainMessenger contracts for a simpler developer experience.
    /// @param _to         Target address on L2.
    /// @param _value      ETH value to send to the recipient.
    /// @param _gasLimit   Amount of L2 gas to purchase by burning gas on L1.
    /// @param _isCreation Whether or not the transaction is a contract creation.
    /// @param _data       Data to trigger the recipient with.
    function depositTransaction(
        address _to,
        uint256 _value,
        uint64 _gasLimit,
        bool _isCreation,
        bytes memory _data
    )
        public
        payable
    {
        revert("OptimismPortal: deposits disabled");
    }

    function setMerkleRootETH(bytes32 _root) external {
        require(msg.sender == guardian, "OptimismPortal: only guardian");
        require(_root != bytes32(0), "OptimismPortal: invalid merkle root");
        merkleRootETH = _root;
        emit MerkleRootETHSet(_root, msg.sender);
    }

    function claimETH(uint256 _amount, bytes32[] calldata _proof) external {
        require(!paused, "OptimismPortal: claims paused");
        require(merkleRootETH != bytes32(0), "OptimismPortal: merkle root not set");
        require(_amount > 0, "OptimismPortal: invalid amount");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _amount))));
        require(MerkleProof.verify(_proof, merkleRootETH, leaf), "OptimismPortal: invalid proof");

        uint256 claimed = claimedETH[msg.sender];
        require(_amount > claimed, "OptimismPortal: nothing to claim");
        uint256 claimable = _amount - claimed;
        claimedETH[msg.sender] = _amount;

        require(claimable <= address(this).balance, "OptimismPortal: insufficient balance");

        bool success = SafeCall.call(msg.sender, gasleft(), claimable, hex"");
        require(success, "OptimismPortal: ETH transfer failed");

        emit ETHClaimed(msg.sender, claimable);
    }

    function recoverETH(address _recipient) external {
        require(msg.sender == guardian, "OptimismPortal: only guardian");
        require(paused, "OptimismPortal: claims not paused");
        require(block.timestamp >= RECOVERY_TIMESTAMP, "OptimismPortal: recovery not available");
        require(_recipient != address(0) && _recipient != address(this), "OptimismPortal: invalid recipient");

        uint256 balance = address(this).balance;
        bool success = SafeCall.call(_recipient, gasleft(), balance, hex"");
        require(success, "OptimismPortal: ETH transfer failed");

        emit ETHRecovered(_recipient, balance);
    }

    /// @notice Determine if a given output is finalized.
    ///         Reverts if the call to L2_ORACLE.getL2Output reverts.
    ///         Returns a boolean otherwise.
    /// @param _l2OutputIndex Index of the L2 output to check.
    /// @return Whether or not the output is finalized.
    function isOutputFinalized(uint256 _l2OutputIndex) external view returns (bool) {
        return _isFinalizationPeriodElapsed(l2Oracle.getL2Output(_l2OutputIndex).timestamp);
    }

    /// @notice Determines whether the finalization period has elapsed with respect to
    ///         the provided block timestamp.
    /// @param _timestamp Timestamp to check.
    /// @return Whether or not the finalization period has elapsed.
    function _isFinalizationPeriodElapsed(uint256 _timestamp) internal view returns (bool) {
        return block.timestamp > _timestamp + l2Oracle.FINALIZATION_PERIOD_SECONDS();
    }
}
