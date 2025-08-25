// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { SuperVault } from "./SuperVault.sol";
import { SuperVaultStrategy } from "./SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "./SuperVaultEscrow.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "../interfaces/SuperVault/ISuperVaultAggregator.sol";
// Libraries
import { AssetMetadataLib } from "../libraries/AssetMetadataLib.sol";

/// @title SuperVaultAggregator
/// @author Superform Labs
/// @notice Registry and PPS oracle for all SuperVaults
/// @dev Creates new SuperVault trios and manages PPS updates
contract SuperVaultAggregator is ISuperVaultAggregator {
    using AssetMetadataLib for address;
    using Clones for address;
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Vault implementation contracts
    address public immutable VAULT_IMPLEMENTATION;
    address public immutable STRATEGY_IMPLEMENTATION;
    address public immutable ESCROW_IMPLEMENTATION;

    // Governance
    ISuperGovernor public immutable SUPER_GOVERNOR;
    
    // Claimable upkeep
    uint256 public claimableUpkeep;

    // Strategy data storage
    mapping(address strategy => StrategyData) private _strategyData;

    // Upkeep balances
    mapping(address strategist => uint256 upkeep) private _strategistUpkeepBalance;


    // Registry of created vaults
    EnumerableSet.AddressSet private _superVaults;
    EnumerableSet.AddressSet private _superVaultStrategies;
    EnumerableSet.AddressSet private _superVaultEscrows;

    // Constant for PPS decimals
    uint256 public constant PPS_DECIMALS = 18;

    // Timelock for strategist changes and Merkle root updates
    uint256 private constant _STRATEGIST_CHANGE_TIMELOCK = 7 days;
    uint256 private _hooksRootUpdateTimelock = 15 minutes;

    // Global hooks Merkle root data
    bytes32 private _globalHooksRoot;
    bytes32 private _proposedGlobalHooksRoot;
    uint256 private _globalHooksRootEffectiveTime;
    bool private _globalHooksRootVetoed;

    // Nonce for vault creation tracking
    uint256 private _vaultCreationNonce;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates that msg.sender is the active PPS Oracle
    modifier onlyPPSOracle() {
        if (!SUPER_GOVERNOR.isActivePPSOracle(msg.sender)) {
            revert UNAUTHORIZED_PPS_ORACLE();
        }
        _;
    }

    /// @notice Validates that a strategy exists (has been created by this aggregator)
    modifier validStrategy(address strategy) {
        if (!_superVaultStrategies.contains(strategy)) revert UNKNOWN_STRATEGY();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the SuperVaultAggregator
    /// @param superGovernor_ Address of the SuperGovernor contract
    /// @param vaultImpl_ Address of the pre-deployed SuperVault implementation
    /// @param strategyImpl_ Address of the pre-deployed SuperVaultStrategy implementation
    /// @param escrowImpl_ Address of the pre-deployed SuperVaultEscrow implementation
    constructor(address superGovernor_, address vaultImpl_, address strategyImpl_, address escrowImpl_) {
        if (superGovernor_ == address(0)) revert ZERO_ADDRESS();
        if (vaultImpl_ == address(0)) revert ZERO_ADDRESS();
        if (strategyImpl_ == address(0)) revert ZERO_ADDRESS();
        if (escrowImpl_ == address(0)) revert ZERO_ADDRESS();

        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
        VAULT_IMPLEMENTATION = vaultImpl_;
        STRATEGY_IMPLEMENTATION = strategyImpl_;
        ESCROW_IMPLEMENTATION = escrowImpl_;
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT CREATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function createVault(VaultCreationParams calldata params)
        external
        returns (address superVault, address strategy, address escrow)
    {
        // Input validation
        if (
            params.asset == address(0) || params.mainStrategist == address(0)
                || params.feeConfig.recipient == address(0)
        ) {
            revert ZERO_ADDRESS();
        }

        // Initialize local variables struct to avoid stack too deep
        VaultCreationLocalVars memory vars;

        // Increment nonce before creating proxies
        vars.currentNonce = _vaultCreationNonce++;
        vars.salt = keccak256(abi.encode(msg.sender, params.asset, params.name, params.symbol, vars.currentNonce));

        // Create minimal proxies
        superVault = VAULT_IMPLEMENTATION.cloneDeterministic(vars.salt);
        escrow = ESCROW_IMPLEMENTATION.cloneDeterministic(vars.salt);
        strategy = STRATEGY_IMPLEMENTATION.cloneDeterministic(vars.salt);

        // Initialize superVault
        SuperVault(superVault).initialize(params.asset, params.name, params.symbol, strategy, escrow);

        // Initialize escrow
        SuperVaultEscrow(escrow).initialize(superVault, strategy);

        // Initialize strategy
        SuperVaultStrategy(payable(strategy)).initialize(superVault, params.feeConfig);

        // Store vault trio in registry
        _superVaults.add(superVault);
        _superVaultStrategies.add(strategy);
        _superVaultEscrows.add(escrow);

        // Get asset decimals
        (bool success, uint8 assetDecimals) = params.asset.tryGetAssetDecimals();
        if (!success) revert INVALID_ASSET();
        vars.initialPPS = 10 ** assetDecimals; // 1.0 as initial PPS

        // Validate maxStaleness against minimum required staleness
        if (params.maxStaleness < SUPER_GOVERNOR.getMinStaleness()) {
            revert MAX_STALENESS_TOO_LOW();
        }

        // Initialize StrategyData individually to avoid mapping assignment issues
        _strategyData[strategy].pps = vars.initialPPS;
        // Initialize standard deviation to 0
        _strategyData[strategy].lastUpdateTimestamp = block.timestamp;
        _strategyData[strategy].minUpdateInterval = params.minUpdateInterval;
        _strategyData[strategy].maxStaleness = params.maxStaleness;
        _strategyData[strategy].isPaused = false;
        _strategyData[strategy].mainStrategist = params.mainStrategist;

        uint256 secondaryLen = params.secondaryStrategists.length;
        for (uint256 i; i < secondaryLen; ++i) {
            _strategyData[strategy].secondaryStrategists.add(params.secondaryStrategists[i]);
        }

        // Set default threshold values
        _strategyData[strategy].dispersionThreshold = type(uint256).max; // Default: max (disabled)
        _strategyData[strategy].deviationThreshold = type(uint256).max; // Default: max (disabled)

        emit VaultDeployed(superVault, strategy, escrow, params.asset, params.name, params.symbol, vars.currentNonce);
        emit PPSUpdated(strategy, vars.initialPPS, 0, 0, 0, _strategyData[strategy].lastUpdateTimestamp);

        return (superVault, strategy, escrow);
    }

    /*//////////////////////////////////////////////////////////////
                          PPS UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function forwardPPS(
        address updateAuthority,
        ForwardPPSArgs calldata args
    )
        external
        onlyPPSOracle
        validStrategy(args.strategy)
    {
        // Check if the update is exempt from paying upkeep
        bool isExempt = _isExemptFromUpkeep(args.strategy, updateAuthority, args.timestamp);

        // Create a new ForwardPPSArgs struct with updated isExempt and upkeepCost
        _forwardPPS(
            ForwardPPSArgs({
                strategy: args.strategy,
                isExempt: isExempt,
                pps: args.pps,
                ppsStdev: args.ppsStdev,
                validatorSet: args.validatorSet,
                totalValidators: args.totalValidators,
                timestamp: args.timestamp,
                upkeepCost: SUPER_GOVERNOR.getUpkeepCostPerUpdate()
            })
        );
    }

    /// @inheritdoc ISuperVaultAggregator
    function batchForwardPPS(BatchForwardPPSArgs calldata args) external onlyPPSOracle {
        uint256 strategiesLength = args.strategies.length;
        // Check array lengths
        if (
            strategiesLength != args.ppss.length || strategiesLength != args.ppsStdevs.length
                || strategiesLength != args.validatorSets.length || strategiesLength != args.timestamps.length
                || strategiesLength != args.totalValidators.length
        ) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        if (strategiesLength == 0) revert ZERO_ARRAY_LENGTH();

        bool upkeepExempt = false;
        uint256 upkeepPerStrategy;

        // Check if upkeep payments are globally disabled in SuperGovernor
        if (SUPER_GOVERNOR.isUpkeepPaymentsEnabled()) {
            // Calculate upkeep cost per strategy
            upkeepPerStrategy = SUPER_GOVERNOR.getUpkeepCostPerUpdate() / strategiesLength;
        } else {
            upkeepExempt = true;
            upkeepPerStrategy = 0;
        }

        // Process all valid strategies
        for (uint256 i; i < strategiesLength; i++) {
            // Skip invalid strategies without reverting
            if (!_superVaultStrategies.contains(args.strategies[i])) continue;

            uint256 upkeepCost = upkeepPerStrategy;
            if (upkeepCost > 0) {
                // check exemption due to staleness of a given strategy
                if (block.timestamp - args.timestamps[i] > _strategyData[args.strategies[i]].maxStaleness) {
                    upkeepCost = 0;
                    emit StaleUpdate(args.strategies[i], address(0), args.timestamps[i]);
                }
            }

            // Forward update, not exempt from upkeep in batch updates
            _forwardPPS(
                ForwardPPSArgs({
                    strategy: args.strategies[i],
                    isExempt: upkeepExempt,
                    pps: args.ppss[i],
                    ppsStdev: args.ppsStdevs[i],
                    validatorSet: args.validatorSets[i],
                    totalValidators: args.totalValidators[i],
                    timestamp: args.timestamps[i],
                    upkeepCost: upkeepCost
                })
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                        UPKEEP MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function depositUpkeep(address strategist, uint256 amount) external {
        if (amount == 0) revert ZERO_ADDRESS(); // Reusing error code for consistency

        // Get the UP token address from SUPER_GOVERNOR
        address upToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.UP());

        // Transfer UP tokens from msg.sender to this contract
        IERC20(upToken).safeTransferFrom(msg.sender, address(this), amount);

        // Update upkeep balance
        _strategistUpkeepBalance[strategist] += amount;

        emit UpkeepDeposited(strategist, amount);
    }

    /// @inheritdoc ISuperVaultAggregator
    function claimUpkeep(uint256 amount) external {
        // Only SUPER_GOVERNOR can claim upkeep
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert CALLER_NOT_AUTHORIZED();
        }

        if (claimableUpkeep < amount) revert INSUFFICIENT_UPKEEP();
        claimableUpkeep -= amount;

        // Get the UP token address from SUPER_GOVERNOR
        address upToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.UP());

        // Transfer UP tokens to `SuperBank`
        address _superBank = _getSuperBank();
        IERC20(upToken).safeTransfer(_superBank, amount);
        emit UpkeepClaimed(_superBank, amount);
    }

    /// @inheritdoc ISuperVaultAggregator
    function withdrawUpkeep(uint256 amount) external {
        if (amount == 0) revert ZERO_ADDRESS(); // Reusing error code for consistency

        // Check sufficient balance
        if (_strategistUpkeepBalance[msg.sender] < amount) {
            revert INSUFFICIENT_UPKEEP_BALANCE();
        }

        // Get the UP token address from SUPER_GOVERNOR
        address upToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.UP());

        // Update upkeep balance
        unchecked {
            _strategistUpkeepBalance[msg.sender] -= amount;
        }

        // Transfer UP tokens to strategist
        IERC20(upToken).safeTransfer(msg.sender, amount);

        emit UpkeepWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZED CALLER MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function addAuthorizedCaller(address strategy, address caller) external validStrategy(strategy) {
        // Either primary or secondary strategist can add authorized callers
        if (!isAnyStrategist(msg.sender, strategy)) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        if (caller == address(0)) revert ZERO_ADDRESS();

        // Prevent strategists from adding protected keepers to circumvent fees
        if (SUPER_GOVERNOR.isProtectedKeeper(caller)) {
            revert CANNOT_ADD_PROTECTED_KEEPER();
        }

        // Check if caller is already authorized and add if not
        if (!_strategyData[strategy].authorizedCallers.add(caller)) {
            revert CALLER_ALREADY_AUTHORIZED();
        }
        emit AuthorizedCallerAdded(strategy, caller);
    }

    /// @inheritdoc ISuperVaultAggregator
    function removeAuthorizedCaller(address strategy, address caller) external validStrategy(strategy) {
        // Either primary or secondary strategist can remove authorized callers
        if (!isAnyStrategist(msg.sender, strategy)) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        // Remove the caller
        if (!_strategyData[strategy].authorizedCallers.remove(caller)) {
            revert CALLER_NOT_AUTHORIZED();
        }
        emit AuthorizedCallerRemoved(strategy, caller);
    }

    /*//////////////////////////////////////////////////////////////
                       STRATEGIST MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function addSecondaryStrategist(address strategy, address strategist) external validStrategy(strategy) {
        // Only the primary strategist can add secondary strategists
        if (msg.sender != _strategyData[strategy].mainStrategist) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        if (strategist == address(0)) revert ZERO_ADDRESS();

        // Check if strategist is already the primary strategist
        if (_strategyData[strategy].mainStrategist == strategist) revert STRATEGIST_ALREADY_EXISTS();

        // Add as secondary strategist using EnumerableSet
        if (!_strategyData[strategy].secondaryStrategists.add(strategist)) revert STRATEGIST_ALREADY_EXISTS();

        emit SecondaryStrategistAdded(strategy, strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function removeSecondaryStrategist(address strategy, address strategist) external validStrategy(strategy) {
        // Only the primary strategist can remove secondary strategists
        if (msg.sender != _strategyData[strategy].mainStrategist) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        // Remove the strategist using EnumerableSet
        if (!_strategyData[strategy].secondaryStrategists.remove(strategist)) revert STRATEGIST_NOT_FOUND();

        emit SecondaryStrategistRemoved(strategy, strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function updatePPSVerificationThresholds(
        address strategy,
        uint256 dispersionThreshold_,
        uint256 deviationThreshold_,
        uint256 mnThreshold_
    )
        external
        validStrategy(strategy)
    {
        // Since this is a risky call, we only allow main strategists as callers
        if (msg.sender != _strategyData[strategy].mainStrategist) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Update the thresholds
        _strategyData[strategy].dispersionThreshold = dispersionThreshold_;
        _strategyData[strategy].deviationThreshold = deviationThreshold_;
        _strategyData[strategy].mnThreshold = mnThreshold_;

        // Emit the event
        emit PPSVerificationThresholdsUpdated(strategy, dispersionThreshold_, deviationThreshold_, mnThreshold_);
    }

    /// @inheritdoc ISuperVaultAggregator
    function changeGlobalLeavesStatus(
        bytes32[] memory leaves,
        bool[] memory statuses,
        address strategy
    )
        external
        validStrategy(strategy)
    {
        // Only the primary strategist can change global leaves status
        if (msg.sender != _strategyData[strategy].mainStrategist) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }
        uint256 leavesLen = leaves.length;
        // Check array lengths match
        if (leavesLen != statuses.length) {
            revert MISMATCHED_ARRAY_LENGTHS();
        }

        // Update banned status for each leaf
        for (uint256 i; i < leavesLen; i++) {
            _strategyData[strategy].bannedLeaves[leaves[i]] = statuses[i];
        }

        // Emit event
        emit GlobalLeavesStatusChanged(strategy, leaves, statuses);
    }

    /// @inheritdoc ISuperVaultAggregator
    function changePrimaryStrategist(address strategy, address newStrategist) external validStrategy(strategy) {
        // Only SuperGovernor can call this
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        if (strategy == address(0)) revert ZERO_ADDRESS();

        if (newStrategist == address(0)) revert ZERO_ADDRESS();

        address oldStrategist = _strategyData[strategy].mainStrategist;

        // SECURITY: Clear any pending strategist proposals to prevent malicious re-takeover
        _strategyData[strategy].proposedStrategist = address(0);
        _strategyData[strategy].strategistChangeEffectiveTime = 0;

        // SECURITY: Clear any pending hooks root proposals to prevent malicious hook updates
        _strategyData[strategy].proposedHooksRoot = bytes32(0);
        _strategyData[strategy].hooksRootEffectiveTime = 0;

        // SECURITY: Clear all secondary strategists as they may be controlled by malicious strategist
        // Get all secondary strategists first to emit proper events
        address[] memory clearedSecondaryStrategists = _strategyData[strategy].secondaryStrategists.values();

        // Clear the entire secondary strategists set
        for (uint256 i = 0; i < clearedSecondaryStrategists.length; i++) {
            _strategyData[strategy].secondaryStrategists.remove(clearedSecondaryStrategists[i]);
            emit SecondaryStrategistRemoved(strategy, clearedSecondaryStrategists[i]);
        }

        // Set the new primary strategist
        _strategyData[strategy].mainStrategist = newStrategist;

        emit PrimaryStrategistChanged(strategy, oldStrategist, newStrategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function proposeChangePrimaryStrategist(address strategy, address newStrategist) external validStrategy(strategy) {
        // Only secondary strategists can propose changes to the primary strategist
        if (!_strategyData[strategy].secondaryStrategists.contains(msg.sender)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        if (newStrategist == address(0)) revert ZERO_ADDRESS();

        // Set up the proposal with 7-day timelock
        uint256 effectiveTime = block.timestamp + _STRATEGIST_CHANGE_TIMELOCK;

        // Store proposal in the strategy data
        _strategyData[strategy].proposedStrategist = newStrategist;
        _strategyData[strategy].strategistChangeEffectiveTime = effectiveTime;

        emit PrimaryStrategistChangeProposed(strategy, msg.sender, newStrategist, effectiveTime);
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeChangePrimaryStrategist(address strategy) external validStrategy(strategy) {
        // Check if there is a pending proposal
        if (_strategyData[strategy].proposedStrategist == address(0)) revert NO_PENDING_STRATEGIST_CHANGE();

        // Check if the timelock period has passed
        if (block.timestamp < _strategyData[strategy].strategistChangeEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        address newStrategist = _strategyData[strategy].proposedStrategist;
        address oldStrategist = _strategyData[strategy].mainStrategist;

        // If new strategist is already a secondary strategist, remove them
        _strategyData[strategy].secondaryStrategists.remove(newStrategist);

        // Make the old primary strategist a secondary strategist
        _strategyData[strategy].secondaryStrategists.add(oldStrategist);

        // Set the new primary strategist
        _strategyData[strategy].mainStrategist = newStrategist;

        // Clear the proposal
        _strategyData[strategy].proposedStrategist = address(0);

        emit PrimaryStrategistChanged(strategy, oldStrategist, newStrategist);
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function setHooksRootUpdateTimelock(uint256 newTimelock) external {
        // Only SUPER_GOVERNOR can update the timelock
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Update the timelock
        _hooksRootUpdateTimelock = newTimelock;

        emit HooksRootUpdateTimelockChanged(newTimelock);
    }

    /// @inheritdoc ISuperVaultAggregator
    function proposeGlobalHooksRoot(bytes32 newRoot) external {
        // Only SUPER_GOVERNOR can update the global hooks root
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Set new root with timelock
        _proposedGlobalHooksRoot = newRoot;
        uint256 effectiveTime = block.timestamp + _hooksRootUpdateTimelock;
        _globalHooksRootEffectiveTime = effectiveTime;

        emit GlobalHooksRootUpdateProposed(newRoot, effectiveTime);
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeGlobalHooksRootUpdate() external {
        bytes32 proposedRoot = _proposedGlobalHooksRoot;
        // Ensure there is a pending proposal
        if (proposedRoot == bytes32(0)) {
            revert NO_PENDING_GLOBAL_ROOT_CHANGE();
        }

        // Check if timelock period has elapsed
        if (block.timestamp < _globalHooksRootEffectiveTime) {
            revert ROOT_UPDATE_NOT_READY();
        }

        // Update the global hooks root
        bytes32 oldRoot = _globalHooksRoot;
        _globalHooksRoot = _proposedGlobalHooksRoot;
        _globalHooksRootEffectiveTime = 0;
        _proposedGlobalHooksRoot = bytes32(0);

        emit GlobalHooksRootUpdated(oldRoot, proposedRoot);
    }

    /// @inheritdoc ISuperVaultAggregator
    function setGlobalHooksRootVetoStatus(bool vetoed) external {
        // Only SuperGovernor can call this
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Don't emit event if status doesn't change
        if (_globalHooksRootVetoed == vetoed) {
            return;
        }

        // Update veto status
        _globalHooksRootVetoed = vetoed;

        emit GlobalHooksRootVetoStatusChanged(vetoed, _globalHooksRoot);
    }

    /// @inheritdoc ISuperVaultAggregator
    function proposeStrategyHooksRoot(address strategy, bytes32 newRoot) external validStrategy(strategy) {
        // Only the main strategist can propose strategy-specific hooks root
        if (_strategyData[strategy].mainStrategist != msg.sender) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Set proposed root with timelock
        _strategyData[strategy].proposedHooksRoot = newRoot;
        uint256 effectiveTime = block.timestamp + _hooksRootUpdateTimelock;
        _strategyData[strategy].hooksRootEffectiveTime = effectiveTime;

        emit StrategyHooksRootUpdateProposed(strategy, msg.sender, newRoot, effectiveTime);
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeStrategyHooksRootUpdate(address strategy) external validStrategy(strategy) {
        bytes32 proposedRoot = _strategyData[strategy].proposedHooksRoot;
        // Ensure there is a pending proposal
        if (proposedRoot == bytes32(0)) {
            revert NO_PENDING_STRATEGIST_CHANGE(); // Reusing error for simplicity
        }

        // Check if timelock period has elapsed
        if (block.timestamp < _strategyData[strategy].hooksRootEffectiveTime) {
            revert ROOT_UPDATE_NOT_READY();
        }

        // Update the strategy's hooks root
        bytes32 oldRoot = _strategyData[strategy].strategistHooksRoot;
        _strategyData[strategy].strategistHooksRoot = proposedRoot;

        // Reset proposal state
        _strategyData[strategy].proposedHooksRoot = bytes32(0);
        _strategyData[strategy].hooksRootEffectiveTime = 0;

        emit StrategyHooksRootUpdated(strategy, oldRoot, proposedRoot);
    }

    /// @inheritdoc ISuperVaultAggregator
    function setStrategyHooksRootVetoStatus(address strategy, bool vetoed) external validStrategy(strategy) {
        // Only SuperGovernor can call this
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Don't emit event if status doesn't change
        if (_strategyData[strategy].hooksRootVetoed == vetoed) {
            return;
        }

        // Update veto status
        _strategyData[strategy].hooksRootVetoed = vetoed;

        emit StrategyHooksRootVetoStatusChanged(strategy, vetoed, _strategyData[strategy].strategistHooksRoot);
    }
    /// @inheritdoc ISuperVaultAggregator

    function isGlobalHooksRootVetoed() external view returns (bool vetoed) {
        return _globalHooksRootVetoed;
    }

    /// @inheritdoc ISuperVaultAggregator
    function isStrategyHooksRootVetoed(address strategy) external view returns (bool vetoed) {
        return _strategyData[strategy].hooksRootVetoed;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVaultAggregator
    function getCurrentNonce() external view returns (uint256) {
        return _vaultCreationNonce;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getHooksRootUpdateTimelock() external view returns (uint256) {
        return _hooksRootUpdateTimelock;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getPPS(address strategy) external view validStrategy(strategy) returns (uint256 pps) {
        return _strategyData[strategy].pps;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getPPSWithStdDev(address strategy)
        external
        view
        validStrategy(strategy)
        returns (uint256 pps, uint256 ppsStdev)
    {
        return (_strategyData[strategy].pps, _strategyData[strategy].ppsStdev);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getLastUpdateTimestamp(address strategy) external view returns (uint256 timestamp) {
        return _strategyData[strategy].lastUpdateTimestamp;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMinUpdateInterval(address strategy) external view returns (uint256 interval) {
        return _strategyData[strategy].minUpdateInterval;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMaxStaleness(address strategy) external view returns (uint256 staleness) {
        return _strategyData[strategy].maxStaleness;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getPPSVerificationThresholds(address strategy)
        external
        view
        validStrategy(strategy)
        returns (uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
    {
        return (
            _strategyData[strategy].dispersionThreshold,
            _strategyData[strategy].deviationThreshold,
            _strategyData[strategy].mnThreshold
        );
    }

    /// @inheritdoc ISuperVaultAggregator
    function isStrategyPaused(address strategy) external view returns (bool isPaused) {
        return _strategyData[strategy].isPaused;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getUpkeepBalance(address strategist) external view returns (uint256 balance) {
        return _strategistUpkeepBalance[strategist];
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAuthorizedCallers(address strategy) external view returns (address[] memory callers) {
        return _strategyData[strategy].authorizedCallers.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMainStrategist(address strategy) external view returns (address strategist) {
        strategist = _strategyData[strategy].mainStrategist;
        if (strategist == address(0)) revert ZERO_ADDRESS();

        return strategist;
    }

    /// @inheritdoc ISuperVaultAggregator
    function isMainStrategist(address strategist, address strategy) external view returns (bool) {
        return _strategyData[strategy].mainStrategist == strategist;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getSecondaryStrategists(address strategy) external view returns (address[] memory) {
        return _strategyData[strategy].secondaryStrategists.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function isSecondaryStrategist(address strategist, address strategy) external view returns (bool) {
        return _strategyData[strategy].secondaryStrategists.contains(strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function isAnyStrategist(address strategist, address strategy) public view returns (bool) {
        // Check if primary strategist
        if (_strategyData[strategy].mainStrategist == strategist) {
            return true;
        }

        // Check if secondary strategist using EnumerableSet
        return _strategyData[strategy].secondaryStrategists.contains(strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaults() external view returns (address[] memory) {
        return _superVaults.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaults(uint256 index) external view returns (address) {
        if (index >= _superVaults.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaults.at(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaultStrategies() external view returns (address[] memory) {
        return _superVaultStrategies.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaultStrategies(uint256 index) external view returns (address) {
        if (index >= _superVaultStrategies.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaultStrategies.at(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaultEscrows() external view returns (address[] memory) {
        return _superVaultEscrows.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaultEscrows(uint256 index) external view returns (address) {
        if (index >= _superVaultEscrows.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaultEscrows.at(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function validateHook(
        address strategy,
        ValidateHookArgs calldata args
    )
        external
        view
        returns (bool isValid)
    {
        // Cache all state variables in struct
        HookValidationCache memory cache = HookValidationCache({
            globalHooksRootVetoed: _globalHooksRootVetoed,
            globalHooksRoot: _globalHooksRoot,
            strategyHooksRootVetoed: _strategyData[strategy].hooksRootVetoed,
            strategyRoot: _strategyData[strategy].strategistHooksRoot
        });

        // Early return false if either global or strategy hooks root is vetoed
        if (cache.globalHooksRootVetoed || cache.strategyHooksRootVetoed) {
            return false;
        }

        // Try to validate against global root first
        if (_validateSingleHook(args.hookAddress, args.hookArgs, args.globalProof, true, cache, strategy)) {
            return true;
        }

        // If global validation fails, try strategy root
        return _validateSingleHook(args.hookAddress, args.hookArgs, args.strategyProof, false, cache, strategy);
    }

    /// @inheritdoc ISuperVaultAggregator
    function validateHooks(
        address strategy,
        ValidateHookArgs[] calldata argsArray
    )
        external
        view
        returns (bool[] memory validHooks)
    {
        uint256 length = argsArray.length;

        // Cache all state variables in struct
        HookValidationCache memory cache = HookValidationCache({
            globalHooksRootVetoed: _globalHooksRootVetoed,
            globalHooksRoot: _globalHooksRoot,
            strategyHooksRootVetoed: _strategyData[strategy].hooksRootVetoed,
            strategyRoot: _strategyData[strategy].strategistHooksRoot
        });

        // Early return all false if either global or strategy hooks root is vetoed
        if (cache.globalHooksRootVetoed || cache.strategyHooksRootVetoed) {
            return new bool[](length); // Array initialized with all false values
        }

        // Validate each hook
        validHooks = new bool[](length);
        for (uint256 i; i < length; i++) {
            // Try global root first
            if (_validateSingleHook(argsArray[i].hookAddress, argsArray[i].hookArgs, argsArray[i].globalProof, true, cache, strategy)) {
                validHooks[i] = true;
            } else {
                // Try strategy root
                validHooks[i] = _validateSingleHook(argsArray[i].hookAddress, argsArray[i].hookArgs, argsArray[i].strategyProof, false, cache, strategy);
            }
            // If both conditions fail, validHooks[i] remains false (default value)
        }

        return validHooks;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getGlobalHooksRoot() external view returns (bytes32 root) {
        return _globalHooksRoot;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getProposedGlobalHooksRoot() external view returns (bytes32 root, uint256 effectiveTime) {
        return (_proposedGlobalHooksRoot, _globalHooksRootEffectiveTime);
    }

    /// @notice Checks if the global hooks root is active (timelock period has passed)
    /// @return isActive True if the global hooks root is active
    function isGlobalHooksRootActive() external view returns (bool) {
        return block.timestamp >= _globalHooksRootEffectiveTime && _globalHooksRoot != bytes32(0);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getStrategyHooksRoot(address strategy) external view returns (bytes32 root) {
        return _strategyData[strategy].strategistHooksRoot;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getProposedStrategyHooksRoot(address strategy)
        external
        view
        returns (bytes32 root, uint256 effectiveTime)
    {
        return (_strategyData[strategy].proposedHooksRoot, _strategyData[strategy].hooksRootEffectiveTime);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Internal implementation of forwarding PPS updates
    /// @param args Struct containing all parameters for PPS update
    function _forwardPPS(ForwardPPSArgs memory args) internal {
        // Check rate limiting
        uint256 minInterval = _strategyData[args.strategy].minUpdateInterval;
        uint256 lastUpdate = _strategyData[args.strategy].lastUpdateTimestamp;
        if (block.timestamp - lastUpdate < minInterval) {
            revert UPDATE_TOO_FREQUENT();
        }

        // Ensure timestamp is monotonically increasing to prevent out-of-order updates
        if (args.timestamp <= lastUpdate) {
            revert TIMESTAMP_NOT_MONOTONIC();
        }

        // Get the strategy's strategist to deduct upkeep cost from
        address strategist = _strategyData[args.strategy].mainStrategist;

        // Flag to track if any check failed
        bool checksFailed = false;

        // C2.1) Dispersion Check: Check if the standard deviation is too high relative to mean
        if (_strategyData[args.strategy].dispersionThreshold != type(uint256).max && args.pps > 0) {
            // Calculate dispersion as stddev/mean
            uint256 dispersion = (args.ppsStdev * 1e18) / args.pps; // Scaled by 1e18 for precision
            if (dispersion > _strategyData[args.strategy].dispersionThreshold) {
                checksFailed = true;
                emit StrategyCheckFailed(args.strategy, "HIGH_PPS_DISPERSION");
            }
        }

        // C2.2) Deviation Check: Check if new PPS deviates too much from current PPS
        uint256 currentPPS = _strategyData[args.strategy].pps;
        if (_strategyData[args.strategy].deviationThreshold != type(uint256).max && currentPPS > 0) {
            // Calculate absolute deviation, scaled by 1e18
            uint256 absDiff = args.pps > currentPPS ? (args.pps - currentPPS) : (currentPPS - args.pps);
            uint256 relativeDeviation = (absDiff * 1e18) / currentPPS;
            if (relativeDeviation > _strategyData[args.strategy].deviationThreshold) {
                checksFailed = true;
                emit StrategyCheckFailed(args.strategy, "HIGH_PPS_DEVIATION");
            }
        }

        // C2.3) M/N Check: Check if enough validators participated
        if (args.totalValidators > 0 && _strategyData[args.strategy].mnThreshold > 0) {
            // Calculate participation rate, scaled by 1e18
            uint256 participationRate = (args.validatorSet * 1e18) / args.totalValidators;
            if (participationRate < _strategyData[args.strategy].mnThreshold) {
                checksFailed = true;
                emit StrategyCheckFailed(args.strategy, "INSUFFICIENT_VALIDATOR_PARTICIPATION");
            }
        }

        // Pause strategy if any check failed
        if (checksFailed && !_strategyData[args.strategy].isPaused) {
            _strategyData[args.strategy].isPaused = true;
            emit StrategyPaused(args.strategy);
        }
        // Unpause strategy if all checks passed and strategy was previously paused
        else if (!checksFailed && _strategyData[args.strategy].isPaused) {
            _strategyData[args.strategy].isPaused = false;
            emit StrategyUnpaused(args.strategy);
        }

        // Handle upkeep costs unless exempt
        if (!args.isExempt) {
            // Check if strategist has sufficient upkeep balance
            if (_strategistUpkeepBalance[strategist] < args.upkeepCost) {
                revert INSUFFICIENT_UPKEEP();
            }

            // Deduct the upkeep cost and emit event
            _strategistUpkeepBalance[strategist] -= args.upkeepCost;

            // Add claimable upkeep for the `feeRecipient`
            claimableUpkeep += args.upkeepCost;

            emit UpkeepSpent(strategist, args.upkeepCost);
        } 

        // Update PPS, ppsStdev and timestamp in StrategyData
        _strategyData[args.strategy].pps = args.pps;
        _strategyData[args.strategy].ppsStdev = args.ppsStdev;
        _strategyData[args.strategy].lastUpdateTimestamp = args.timestamp;

        emit PPSUpdated(args.strategy, args.pps, args.ppsStdev, args.validatorSet, args.totalValidators, args.timestamp);
    }

    /// @notice Check if an update authority is exempt from paying upkeep costs
    /// @param strategy Address of the strategy being updated
    /// @param updateAuthority Address initiating the update
    /// @param timestamp Timestamp of the PPS measurement
    /// @return isExempt True if the authority is exempt from paying upkeep
    function _isExemptFromUpkeep(
        address strategy,
        address updateAuthority,
        uint256 timestamp
    )
        internal
        returns (bool)
    {
        // Check if upkeep payments are globally disabled in SuperGovernor
        if (!SUPER_GOVERNOR.isUpkeepPaymentsEnabled()) {
            return true;
        }

        // Update is exempt if it is stale
        if (block.timestamp - timestamp > _strategyData[strategy].maxStaleness) {
            emit StaleUpdate(strategy, updateAuthority, timestamp);
            return true;
        }

        // If strategist is a superform strategist, they're exempt from upkeep fees
        address strategist = _strategyData[strategy].mainStrategist;
        if (SUPER_GOVERNOR.isSuperformStrategist(strategist)) {
            return true;
        }

        // Check if the updateAuthority is in the authorized callers list
        // These are strategist-designated keepers that should be exempt from fees
        // NOTE: Protected keepers cannot be added to this list (blocked in addAuthorizedCaller)
        if (_strategyData[strategy].authorizedCallers.contains(updateAuthority)) {
            return true;
        }

        return false;
    }

    /// @notice Creates a leaf node for Merkle verification from hook address and arguments
    /// @param hookAddress The address of the hook contract
    /// @param hookArgs The packed-encoded hook arguments (from solidityPack in JS)
    /// @return leaf The leaf node hash
    function _createLeaf(address hookAddress, bytes calldata hookArgs) internal pure returns (bytes32) {
        /// @dev The leaf now includes both hook address and args to prevent cross-hook replay attacks
        /// @dev Different hooks with identical encoded args will have different authorization leaves
        /// @dev This matches StandardMerkleTree's standardLeafHash: keccak256(keccak256(abi.encode(hookAddress,
        /// hookArgs)))
        /// @dev but uses bytes.concat for explicit concatenation
        return keccak256(bytes.concat(keccak256(abi.encode(hookAddress, hookArgs))));
    }

    /**
     * @dev Internal function to validate a single hook against either global or strategy root
     * @param hookAddress The address of the hook contract
     * @param hookArgs Hook arguments
     * @param proof Merkle proof for the specified root
     * @param isGlobalProof Whether to validate against global root (true) or strategy root (false)
     * @param cache Cached hook validation state variables
     * @param strategy Address of the strategy (needed to check banned leaves for global proofs)
     * @return True if hook is valid, false otherwise
     */
    function _validateSingleHook(
        address hookAddress,
        bytes calldata hookArgs,
        bytes32[] calldata proof,
        bool isGlobalProof,
        HookValidationCache memory cache,
        address strategy
    )
        internal
        view
        returns (bool)
    {
        // Create leaf node from the hook address and arguments
        bytes32 leaf = _createLeaf(hookAddress, hookArgs);

        if (isGlobalProof) {
            // Validate against global root
            if (cache.globalHooksRootVetoed || cache.globalHooksRoot == bytes32(0)) {
                return false;
            }

            // Check if this leaf is banned by the strategist
            if (_strategyData[strategy].bannedLeaves[leaf]) {
                return false;
            }

            // For single-leaf trees, empty proof is valid when root equals leaf
            if (proof.length == 0) {
                return cache.globalHooksRoot == leaf;
            }
            return MerkleProof.verify(proof, cache.globalHooksRoot, leaf);
        } else {
            // Validate against strategy root
            if (cache.strategyHooksRootVetoed || cache.strategyRoot == bytes32(0)) {
                return false;
            }
            // For single-leaf trees, empty proof is valid when root equals leaf
            if (proof.length == 0) {
                return cache.strategyRoot == leaf;
            }
            return MerkleProof.verify(proof, cache.strategyRoot, leaf);
        }
    }

    /**
     * @dev Internal function to return the `SuperBank` address
     * @return superBank The superBank address
     */
    function _getSuperBank() internal view returns (address) {
        return SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUPER_BANK());
    }
}
