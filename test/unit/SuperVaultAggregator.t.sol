// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SuperGovernor } from "../../src/SuperGovernor.sol";
import { SuperVaultAggregator } from "../../src/SuperVault/SuperVaultAggregator.sol";
import { ISuperVaultAggregator } from "../../src/interfaces/SuperVault/ISuperVaultAggregator.sol";
import { SuperVault } from "../../src/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../../src/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../src/SuperVault/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../src/interfaces/SuperVault/ISuperVaultStrategy.sol";
import { PeripheryHelpers } from "../utils/PeripheryHelpers.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

contract SuperVaultAggregatorTest is PeripheryHelpers {
    SuperGovernor internal superGovernor;
    SuperVaultAggregator internal superVaultAggregator;

    // Roles & Addresses
    address internal sGovernor;
    address internal governor;
    address internal treasury;
    address internal user;
    address internal strategist;
    address internal secondaryStrategist;
    address internal protectedKeeper1;
    address internal protectedKeeper2;
    address internal normalKeeper1;
    address internal normalKeeper2;
    address internal strategy;

    // Role Hashes
    bytes32 internal constant SUPER_GOVERNOR_ROLE = keccak256("SUPER_GOVERNOR_ROLE");
    bytes32 internal constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    MockERC20 internal asset;

    /// @notice Sets up the test environment before each test case.
    function setUp() public {
        // Deploy accounts
        sGovernor = _deployAccount(0x1, "SuperGovernor");
        governor = _deployAccount(0x2, "Governor");
        treasury = _deployAccount(0x3, "Treasury");
        user = _deployAccount(0x4, "User");
        strategist = _deployAccount(0x5, "Strategist");
        secondaryStrategist = _deployAccount(0x6, "SecondaryStrategist");
        protectedKeeper1 = _deployAccount(0x7, "ProtectedKeeper1");
        protectedKeeper2 = _deployAccount(0x8, "ProtectedKeeper2");
        normalKeeper1 = _deployAccount(0x9, "NormalKeeper1");
        normalKeeper2 = _deployAccount(0xA, "NormalKeeper2");

        // Deploy contracts
        asset = new MockERC20("Asset", "ASSET", 18);
        superGovernor = new SuperGovernor(sGovernor, governor, governor, treasury, address(this));

        // Deploy implementation contracts
        address vaultImpl = address(new SuperVault(address(superGovernor)));
        address strategyImpl = address(new SuperVaultStrategy(address(superGovernor)));
        address escrowImpl = address(new SuperVaultEscrow());

        superVaultAggregator = new SuperVaultAggregator(address(superGovernor), vaultImpl, strategyImpl, escrowImpl);

        // Create a vault and strategy for testing
        vm.prank(strategist);
        (, address strategyAddress,) = superVaultAggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                mainStrategist: strategist,
                name: "Test Vault",
                symbol: "TV",
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: strategist })
            })
        );
        strategy = strategyAddress;

        // Add secondary strategist for testing
        vm.prank(strategist);
        superVaultAggregator.addSecondaryStrategist(strategy, secondaryStrategist);

        // Register some protected keepers
        vm.startPrank(governor);
        superGovernor.registerProtectedKeeper(protectedKeeper1);
        superGovernor.registerProtectedKeeper(protectedKeeper2);
        vm.stopPrank();
    }

    // =============================================================
    // Authorized Caller Management Tests
    // =============================================================

    /// @notice Tests adding a normal (non-protected) keeper as authorized caller
    function test_AddAuthorizedCaller_Success_NormalKeeper() public {
        // Primary strategist adds normal keeper
        vm.prank(strategist);
        vm.expectEmit(true, true, false, false);
        emit ISuperVaultAggregator.AuthorizedCallerAdded(strategy, normalKeeper1);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);

        // Verify the keeper was added
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 1, "Should have 1 authorized caller");
        assertEq(callers[0], normalKeeper1, "Authorized caller should match");
    }

    /// @notice Tests secondary strategist can add authorized callers
    function test_AddAuthorizedCaller_Success_SecondaryStrategist() public {
        // Secondary strategist adds normal keeper
        vm.prank(secondaryStrategist);
        vm.expectEmit(true, true, false, false);
        emit ISuperVaultAggregator.AuthorizedCallerAdded(strategy, normalKeeper1);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);

        // Verify the keeper was added
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 1, "Should have 1 authorized caller");
        assertEq(callers[0], normalKeeper1, "Authorized caller should match");
    }

    /// @notice Tests adding multiple normal keepers as authorized callers
    function test_AddAuthorizedCaller_Success_MultipleKeepers() public {
        vm.startPrank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper2);
        vm.stopPrank();

        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 2, "Should have 2 authorized callers");

        // Verify both keepers are in the list
        bool foundKeeper1 = false;
        bool foundKeeper2 = false;
        for (uint256 i = 0; i < callers.length; i++) {
            if (callers[i] == normalKeeper1) foundKeeper1 = true;
            if (callers[i] == normalKeeper2) foundKeeper2 = true;
        }
        assertTrue(foundKeeper1, "normalKeeper1 should be in authorized callers");
        assertTrue(foundKeeper2, "normalKeeper2 should be in authorized callers");
    }

    /// @notice Tests reverting when strategist tries to add protected keeper
    function test_AddAuthorizedCaller_Revert_ProtectedKeeper() public {
        // Primary strategist tries to add protected keeper
        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.CANNOT_ADD_PROTECTED_KEEPER.selector);
        superVaultAggregator.addAuthorizedCaller(strategy, protectedKeeper1);

        // Secondary strategist tries to add protected keeper
        vm.prank(secondaryStrategist);
        vm.expectRevert(ISuperVaultAggregator.CANNOT_ADD_PROTECTED_KEEPER.selector);
        superVaultAggregator.addAuthorizedCaller(strategy, protectedKeeper2);

        // Verify no callers were added
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 0, "Should have 0 authorized callers");
    }

    /// @notice Tests reverting when non-strategist tries to add authorized caller
    function test_AddAuthorizedCaller_Revert_UnauthorizedCaller() public {
        vm.prank(user);
        vm.expectRevert(ISuperVaultAggregator.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);
    }

    /// @notice Tests reverting when adding zero address as authorized caller
    function test_AddAuthorizedCaller_Revert_ZeroAddress() public {
        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.ZERO_ADDRESS.selector);
        superVaultAggregator.addAuthorizedCaller(strategy, address(0));
    }

    /// @notice Tests reverting when adding duplicate authorized caller
    function test_AddAuthorizedCaller_Revert_AlreadyAuthorized() public {
        // Add keeper first
        vm.prank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);

        // Try to add same keeper again
        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.CALLER_ALREADY_AUTHORIZED.selector);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);
    }

    /// @notice Tests reverting when trying to add authorized caller for unknown strategy
    function test_AddAuthorizedCaller_Revert_UnknownStrategy() public {
        address unknownStrategy = _deployAccount(0x99, "UnknownStrategy");

        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.UNKNOWN_STRATEGY.selector);
        superVaultAggregator.addAuthorizedCaller(unknownStrategy, normalKeeper1);
    }

    // =============================================================
    // Remove Authorized Caller Tests
    // =============================================================

    /// @notice Tests removing authorized caller successfully
    function test_RemoveAuthorizedCaller_Success() public {
        // Add caller first
        vm.prank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);

        // Remove caller
        vm.prank(strategist);
        vm.expectEmit(true, true, false, false);
        emit ISuperVaultAggregator.AuthorizedCallerRemoved(strategy, normalKeeper1);
        superVaultAggregator.removeAuthorizedCaller(strategy, normalKeeper1);

        // Verify caller was removed
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 0, "Should have 0 authorized callers");
    }

    /// @notice Tests removing authorized caller when multiple exist
    function test_RemoveAuthorizedCaller_Success_WithMultiple() public {
        // Add multiple callers
        vm.startPrank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper2);
        vm.stopPrank();

        // Remove one caller
        vm.prank(strategist);
        superVaultAggregator.removeAuthorizedCaller(strategy, normalKeeper1);

        // Verify only normalKeeper2 remains
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 1, "Should have 1 authorized caller");
        assertEq(callers[0], normalKeeper2, "Remaining caller should be normalKeeper2");
    }

    /// @notice Tests reverting when removing non-existent authorized caller
    function test_RemoveAuthorizedCaller_Revert_CallerNotFound() public {
        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.CALLER_NOT_AUTHORIZED.selector);
        superVaultAggregator.removeAuthorizedCaller(strategy, normalKeeper1);
    }

    /// @notice Tests secondary strategist can remove authorized callers
    function test_RemoveAuthorizedCaller_Success_SecondaryStrategist() public {
        // Add caller with primary strategist
        vm.prank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);

        // Remove caller with secondary strategist
        vm.prank(secondaryStrategist);
        superVaultAggregator.removeAuthorizedCaller(strategy, normalKeeper1);

        // Verify caller was removed
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 0, "Should have 0 authorized callers");
    }

    // =============================================================
    // Security Integration Tests
    // =============================================================

    /// @notice Tests that previously added keepers become blocked if later protected
    function test_Security_KeeperProtectedAfterAdding() public {
        // Add a normal keeper
        vm.prank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);

        // Verify keeper was added
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 1, "Should have 1 authorized caller");

        // Governance protects the keeper
        vm.prank(governor);
        superGovernor.registerProtectedKeeper(normalKeeper1);

        // Strategist should no longer be able to add the same keeper to other strategies
        // (Create another strategy for testing)
        vm.prank(strategist);
        (, address strategy2,) = superVaultAggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                mainStrategist: strategist,
                name: "Test Vault 2",
                symbol: "TV2",
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: strategist })
            })
        );

        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.CANNOT_ADD_PROTECTED_KEEPER.selector);
        superVaultAggregator.addAuthorizedCaller(strategy2, normalKeeper1);

        // But the keeper should still be in the original strategy's list
        callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 1, "Original strategy should still have the keeper");
        assertEq(callers[0], normalKeeper1, "Original strategy keeper should match");
    }

    /// @notice Tests that unprotecting a keeper allows it to be added again
    function test_Security_KeeperUnprotectedAllowsAdding() public {
        // Governance unprotects a previously protected keeper
        vm.prank(governor);
        superGovernor.unregisterProtectedKeeper(protectedKeeper1);

        // Now strategist should be able to add it
        vm.prank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, protectedKeeper1);

        // Verify keeper was added
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 1, "Should have 1 authorized caller");
        assertEq(callers[0], protectedKeeper1, "Authorized caller should be former protected keeper");
    }

    /// @notice Tests complex scenario with multiple strategists and protected keepers
    function test_Security_ComplexScenario() public {
        // Create another strategy with different strategist
        address strategist2 = _deployAccount(0xB, "Strategist2");
        vm.prank(strategist2);
        (, address strategy2,) = superVaultAggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                mainStrategist: strategist2,
                name: "Test Vault 2",
                symbol: "TV2",
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: strategist2 })
            })
        );

        // Both strategists can add normal keepers
        vm.prank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, normalKeeper1);

        vm.prank(strategist2);
        superVaultAggregator.addAuthorizedCaller(strategy2, normalKeeper2);

        // Neither can add protected keepers
        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.CANNOT_ADD_PROTECTED_KEEPER.selector);
        superVaultAggregator.addAuthorizedCaller(strategy, protectedKeeper1);

        vm.prank(strategist2);
        vm.expectRevert(ISuperVaultAggregator.CANNOT_ADD_PROTECTED_KEEPER.selector);
        superVaultAggregator.addAuthorizedCaller(strategy2, protectedKeeper2);

        // Verify normal keepers were added successfully
        address[] memory callers1 = superVaultAggregator.getAuthorizedCallers(strategy);
        address[] memory callers2 = superVaultAggregator.getAuthorizedCallers(strategy2);

        assertEq(callers1.length, 1, "Strategy 1 should have 1 caller");
        assertEq(callers2.length, 1, "Strategy 2 should have 1 caller");
        assertEq(callers1[0], normalKeeper1, "Strategy 1 caller should match");
        assertEq(callers2[0], normalKeeper2, "Strategy 2 caller should match");
    }

    /// @notice Tests that the strategist themselves can be added as authorized caller (if not protected)
    function test_Security_StrategistCanAddSelf() public {
        // Strategist adds themselves as authorized caller
        vm.prank(strategist);
        superVaultAggregator.addAuthorizedCaller(strategy, strategist);

        // Verify strategist was added
        address[] memory callers = superVaultAggregator.getAuthorizedCallers(strategy);
        assertEq(callers.length, 1, "Should have 1 authorized caller");
        assertEq(callers[0], strategist, "Authorized caller should be strategist");
    }

    /// @notice Tests that protected strategist cannot be added as authorized caller
    function test_Security_ProtectedStrategistCannotBeAdded() public {
        // Protect the strategist
        vm.prank(governor);
        superGovernor.registerProtectedKeeper(strategist);

        // Strategist tries to add themselves but should fail
        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.CANNOT_ADD_PROTECTED_KEEPER.selector);
        superVaultAggregator.addAuthorizedCaller(strategy, strategist);

        // Secondary strategist also cannot add the protected primary strategist
        vm.prank(secondaryStrategist);
        vm.expectRevert(ISuperVaultAggregator.CANNOT_ADD_PROTECTED_KEEPER.selector);
        superVaultAggregator.addAuthorizedCaller(strategy, strategist);
    }

    // =============================================================
    // Monotonic Timestamp Validation Tests
    // =============================================================

    /// @notice Tests that PPS updates with non-monotonic timestamps are rejected
    function test_ForwardPPS_Revert_NonMonotonicTimestamp() public {
        // Set up as PPS Oracle to be able to call forwardPPS
        vm.prank(sGovernor);
        superGovernor.setActivePPSOracle(address(this));

        // Get initial timestamp
        uint256 initialTimestamp = superVaultAggregator.getLastUpdateTimestamp(strategy);

        // Wait for minimum interval to pass to avoid rate limiting error
        vm.warp(block.timestamp + 10); // minUpdateInterval is 5 seconds

        // Try to update with an older timestamp (should revert)
        uint256 olderTimestamp = initialTimestamp - 1;
        vm.expectRevert(ISuperVaultAggregator.TIMESTAMP_NOT_MONOTONIC.selector);
        superVaultAggregator.forwardPPS(
            user,
            ISuperVaultAggregator.ForwardPPSArgs({
                strategy: strategy,
                isExempt: true, // Upkeep is disabled by default
                pps: 1e18,
                ppsStdev: 0,
                validatorSet: 1,
                totalValidators: 1,
                timestamp: olderTimestamp,
                upkeepCost: 0
            })
        );

        // Try to update with the same timestamp (should also revert)
        vm.expectRevert(ISuperVaultAggregator.TIMESTAMP_NOT_MONOTONIC.selector);
        superVaultAggregator.forwardPPS(
            user,
            ISuperVaultAggregator.ForwardPPSArgs({
                strategy: strategy,
                isExempt: true, // Upkeep is disabled by default
                pps: 1e18,
                ppsStdev: 0,
                validatorSet: 1,
                totalValidators: 1,
                timestamp: initialTimestamp,
                upkeepCost: 0
            })
        );
    }

    /// @notice Tests that PPS updates with monotonic increasing timestamps succeed
    function test_ForwardPPS_Success_MonotonicTimestamp() public {
        // Set up as PPS Oracle to be able to call forwardPPS
        vm.prank(sGovernor);
        superGovernor.setActivePPSOracle(address(this));

        // Get initial timestamp
        uint256 initialTimestamp = superVaultAggregator.getLastUpdateTimestamp(strategy);

        // Update with a newer timestamp (should succeed)
        uint256 newerTimestamp = initialTimestamp + 10;

        // Wait for minimum interval to pass
        vm.warp(block.timestamp + 10);

        vm.expectEmit(true, false, false, false);
        emit ISuperVaultAggregator.PPSUpdated(strategy, 1e18, 0, 1, 1, newerTimestamp);

        superVaultAggregator.forwardPPS(
            user,
            ISuperVaultAggregator.ForwardPPSArgs({
                strategy: strategy,
                isExempt: true, // Upkeep is disabled by default in SuperGovernor
                pps: 1e18,
                ppsStdev: 0,
                validatorSet: 1,
                totalValidators: 1,
                timestamp: newerTimestamp,
                upkeepCost: 0
            })
        );

        // Verify timestamp was updated
        assertEq(superVaultAggregator.getLastUpdateTimestamp(strategy), newerTimestamp);
    }

    /// @notice Tests that batch PPS updates with non-monotonic timestamps are rejected
    function test_BatchForwardPPS_Revert_NonMonotonicTimestamp() public {
        // Set up as PPS Oracle to be able to call batchForwardPPS
        vm.prank(sGovernor);
        superGovernor.setActivePPSOracle(address(this));

        // Create second strategy for batch testing
        vm.prank(strategist);
        (, address strategy2,) = superVaultAggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                mainStrategist: strategist,
                name: "Test Vault 2",
                symbol: "TV2",
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: strategist })
            })
        );

        // Get initial timestamps
        uint256 timestamp1 = superVaultAggregator.getLastUpdateTimestamp(strategy);
        uint256 timestamp2 = superVaultAggregator.getLastUpdateTimestamp(strategy2);

        // Prepare batch data with one non-monotonic timestamp
        address[] memory strategies = new address[](2);
        strategies[0] = strategy;
        strategies[1] = strategy2;

        uint256[] memory ppss = new uint256[](2);
        ppss[0] = 1e18;
        ppss[1] = 1e18;

        uint256[] memory ppsStdevs = new uint256[](2);
        ppsStdevs[0] = 0;
        ppsStdevs[1] = 0;

        uint256[] memory validatorSets = new uint256[](2);
        validatorSets[0] = 1;
        validatorSets[1] = 1;

        uint256[] memory totalValidators = new uint256[](2);
        totalValidators[0] = 1;
        totalValidators[1] = 1;

        uint256[] memory timestamps = new uint256[](2);
        timestamps[0] = timestamp1 + 10; // Valid newer timestamp
        timestamps[1] = timestamp2 - 1; // Invalid older timestamp

        // Wait for minimum interval to pass
        vm.warp(block.timestamp + 10);

        // Batch update should revert due to non-monotonic timestamp in strategy2
        vm.expectRevert(ISuperVaultAggregator.TIMESTAMP_NOT_MONOTONIC.selector);
        superVaultAggregator.batchForwardPPS(
            ISuperVaultAggregator.BatchForwardPPSArgs({
                strategies: strategies,
                ppss: ppss,
                ppsStdevs: ppsStdevs,
                validatorSets: validatorSets,
                totalValidators: totalValidators,
                timestamps: timestamps
            })
        );

        // Verify original timestamps are unchanged
        assertEq(superVaultAggregator.getLastUpdateTimestamp(strategy), timestamp1);
        assertEq(superVaultAggregator.getLastUpdateTimestamp(strategy2), timestamp2);
    }

    /// @notice Tests that batch PPS updates with all monotonic timestamps succeed
    function test_BatchForwardPPS_Success_MonotonicTimestamps() public {
        // Set up as PPS Oracle to be able to call batchForwardPPS
        vm.prank(sGovernor);
        superGovernor.setActivePPSOracle(address(this));

        // Create second strategy for batch testing
        vm.prank(strategist);
        (, address strategy2,) = superVaultAggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                mainStrategist: strategist,
                name: "Test Vault 2",
                symbol: "TV2",
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: strategist })
            })
        );

        // Get initial timestamps
        uint256 timestamp1 = superVaultAggregator.getLastUpdateTimestamp(strategy);
        uint256 timestamp2 = superVaultAggregator.getLastUpdateTimestamp(strategy2);

        // Prepare batch data with monotonic timestamps
        address[] memory strategies = new address[](2);
        strategies[0] = strategy;
        strategies[1] = strategy2;

        uint256[] memory ppss = new uint256[](2);
        ppss[0] = 1e18;
        ppss[1] = 1e18;

        uint256[] memory ppsStdevs = new uint256[](2);
        ppsStdevs[0] = 0;
        ppsStdevs[1] = 0;

        uint256[] memory validatorSets = new uint256[](2);
        validatorSets[0] = 1;
        validatorSets[1] = 1;

        uint256[] memory totalValidators = new uint256[](2);
        totalValidators[0] = 1;
        totalValidators[1] = 1;

        uint256[] memory timestamps = new uint256[](2);
        timestamps[0] = timestamp1 + 10; // Valid newer timestamp
        timestamps[1] = timestamp2 + 10; // Valid newer timestamp

        // Wait for minimum interval to pass
        vm.warp(block.timestamp + 10);

        // Batch update should succeed
        superVaultAggregator.batchForwardPPS(
            ISuperVaultAggregator.BatchForwardPPSArgs({
                strategies: strategies,
                ppss: ppss,
                ppsStdevs: ppsStdevs,
                validatorSets: validatorSets,
                totalValidators: totalValidators,
                timestamps: timestamps
            })
        );

        // Verify timestamps were updated
        assertEq(superVaultAggregator.getLastUpdateTimestamp(strategy), timestamps[0]);
        assertEq(superVaultAggregator.getLastUpdateTimestamp(strategy2), timestamps[1]);
    }

    /// @notice Tests that batch PPS updates with stale strategy have upkeepCost set to 0
    function test_BatchForwardPPS_StaleStrategy_UpkeepCostZero() public {
        // Set up as PPS Oracle to be able to call batchForwardPPS
        vm.prank(sGovernor);
        superGovernor.setActivePPSOracle(address(this));

        // Enable upkeep payments so that staleness check can trigger
        vm.prank(sGovernor);
        superGovernor.proposeUpkeepPaymentsChange(true);

        // Wait for the proposal to become effective and execute it
        vm.warp(block.timestamp + 7 days);
        superGovernor.executeUpkeepPaymentsChange();

        // Create second strategy for batch testing with shorter maxStaleness
        vm.prank(strategist);
        (, address strategy2,) = superVaultAggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                mainStrategist: strategist,
                name: "Test Vault 2",
                symbol: "TV2",
                minUpdateInterval: 5,
                maxStaleness: 400, // Shorter staleness period for testing (must be >= minStaleness of 300)
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: strategist })
            })
        );

        // Get initial timestamps
        uint256 timestamp1 = superVaultAggregator.getLastUpdateTimestamp(strategy);
        uint256 timestamp2 = superVaultAggregator.getLastUpdateTimestamp(strategy2);

        // Fast forward time to make strategy2 stale (beyond maxStaleness of 400 seconds)
        vm.warp(block.timestamp + 450);

        // Prepare batch data where strategy2 will be stale
        address[] memory strategies = new address[](2);
        strategies[0] = strategy;
        strategies[1] = strategy2;

        uint256[] memory ppss = new uint256[](2);
        ppss[0] = 1e18;
        ppss[1] = 1e18;

        uint256[] memory ppsStdevs = new uint256[](2);
        ppsStdevs[0] = 0;
        ppsStdevs[1] = 0;

        uint256[] memory validatorSets = new uint256[](2);
        validatorSets[0] = 1;
        validatorSets[1] = 1;

        uint256[] memory totalValidators = new uint256[](2);
        totalValidators[0] = 1;
        totalValidators[1] = 1;

        uint256[] memory timestamps = new uint256[](2);
        timestamps[0] = timestamp1 + 150; // Valid newer timestamp for strategy1
        timestamps[1] = timestamp2 + 40; // This will be stale for strategy2 (block.timestamp=151, submitted=41,
            // diff=110 > maxStaleness=100)

        // Expect StaleUpdate event to be emitted for strategy2
        vm.expectEmit(true, true, false, true);
        emit ISuperVaultAggregator.StaleUpdate(strategy2, address(0), timestamps[1]);

        // Batch update should succeed but strategy2 should have upkeepCost = 0 due to staleness
        superVaultAggregator.batchForwardPPS(
            ISuperVaultAggregator.BatchForwardPPSArgs({
                strategies: strategies,
                ppss: ppss,
                ppsStdevs: ppsStdevs,
                validatorSets: validatorSets,
                totalValidators: totalValidators,
                timestamps: timestamps
            })
        );

        // Verify timestamps were updated for both strategies
        assertEq(superVaultAggregator.getLastUpdateTimestamp(strategy), timestamps[0]);
        assertEq(superVaultAggregator.getLastUpdateTimestamp(strategy2), timestamps[1]);
    }
}
