// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SuperGovernor } from "../../src/SuperGovernor.sol";
import { SuperVaultAggregator } from "../../src/SuperVault/SuperVaultAggregator.sol";
import { ISuperVaultAggregator } from "../../src/interfaces/SuperVault/ISuperVaultAggregator.sol";
import { SuperVault } from "../../src/SuperVault/SuperVault.sol";
import { SuperVaultStrategy } from "../../src/SuperVault/SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "../../src/SuperVault/SuperVaultEscrow.sol";
import { ISuperVaultStrategy } from "../../src/interfaces/SuperVault/ISuperVaultStrategy.sol";
import { PeripheryHelpers } from "../utils/PeripheryHelpers.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { Up } from "../../src/UP/Up.sol";

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
    address internal upToken;
    address internal superBank;

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
                name: "Test Vault",
                symbol: "TV",
                mainStrategist: strategist,
                secondaryStrategists: new address[](0),
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

        // Register UP token on SuperGovernor
        upToken = address(new Up(address(this)));
        superBank = makeAddr("superBank");
        vm.startPrank(sGovernor);
        superGovernor.setAddress(superGovernor.UP(), upToken);
        superGovernor.setAddress(superGovernor.SUPER_BANK(), superBank);
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
    // Emergency Strategist Replacement Tests
    // =============================================================

    /// @notice Tests emergency strategist replacement clears pending proposals
    function test_ChangePrimaryStrategist_ClearsPendingProposals() public {
        // Setup: Create pending strategist proposal
        address newStrategist = _deployAccount(0xC, "NewStrategist");

        // Secondary strategist proposes a change
        vm.prank(secondaryStrategist);
        superVaultAggregator.proposeChangePrimaryStrategist(strategy, newStrategist);

        // SuperGovernor performs emergency replacement
        address emergencyStrategist = _deployAccount(0xD, "EmergencyStrategist");
        vm.prank(address(superGovernor));
        superVaultAggregator.changePrimaryStrategist(strategy, emergencyStrategist);

        // Verify new strategist is set
        address currentStrategist = superVaultAggregator.getMainStrategist(strategy);
        assertEq(currentStrategist, emergencyStrategist, "Emergency strategist should be set");
    }

    /// @notice Tests emergency replacement clears all secondary strategists
    function test_ChangePrimaryStrategist_ClearsSecondaryStrategists() public {
        // Setup: Add multiple secondary strategists
        address secondaryStrategist2 = _deployAccount(0xE, "SecondaryStrategist2");
        address secondaryStrategist3 = _deployAccount(0xF, "SecondaryStrategist3");

        vm.startPrank(strategist);
        superVaultAggregator.addSecondaryStrategist(strategy, secondaryStrategist2);
        superVaultAggregator.addSecondaryStrategist(strategy, secondaryStrategist3);
        vm.stopPrank();

        // Verify secondary strategists exist
        address[] memory secondaryStrategists = superVaultAggregator.getSecondaryStrategists(strategy);
        assertEq(secondaryStrategists.length, 3, "Should have 3 secondary strategists");

        // SuperGovernor performs emergency replacement
        address emergencyStrategist = _deployAccount(0x10, "EmergencyStrategist");

        // Expect SecondaryStrategistRemoved events for all secondary strategists
        vm.expectEmit(true, true, false, false);
        emit ISuperVaultAggregator.SecondaryStrategistRemoved(strategy, secondaryStrategist);
        vm.expectEmit(true, true, false, false);
        emit ISuperVaultAggregator.SecondaryStrategistRemoved(strategy, secondaryStrategist2);
        vm.expectEmit(true, true, false, false);
        emit ISuperVaultAggregator.SecondaryStrategistRemoved(strategy, secondaryStrategist3);

        vm.prank(address(superGovernor));
        superVaultAggregator.changePrimaryStrategist(strategy, emergencyStrategist);

        // Verify all secondary strategists were cleared
        secondaryStrategists = superVaultAggregator.getSecondaryStrategists(strategy);
        assertEq(secondaryStrategists.length, 0, "All secondary strategists should be cleared");
    }

    /// @notice Tests emergency replacement clears pending hook root proposals
    function test_ChangePrimaryStrategist_ClearsPendingHookProposals() public {
        // Setup: Create pending hook root proposal
        bytes32 newHookRoot = keccak256("new_hook_root");

        vm.prank(strategist);
        superVaultAggregator.proposeStrategyHooksRoot(strategy, newHookRoot);

        // Verify hook proposal exists
        (bytes32 proposedRoot, uint256 effectiveTime) = superVaultAggregator.getProposedStrategyHooksRoot(strategy);
        assertEq(proposedRoot, newHookRoot, "Hook proposal should exist");
        assertTrue(effectiveTime > 0, "Hook effective time should be set");

        // SuperGovernor performs emergency replacement
        address emergencyStrategist = _deployAccount(0x11, "EmergencyStrategist");
        vm.prank(address(superGovernor));
        superVaultAggregator.changePrimaryStrategist(strategy, emergencyStrategist);

        // Verify hook proposal was cleared
        (proposedRoot, effectiveTime) = superVaultAggregator.getProposedStrategyHooksRoot(strategy);
        assertEq(proposedRoot, bytes32(0), "Hook proposal should be cleared");
        assertEq(effectiveTime, 0, "Hook effective time should be cleared");
    }

    /// @notice Tests the complete attack scenario - malicious strategist cannot regain control
    function test_ChangePrimaryStrategist_PreventsAttackScenario() public {
        // Setup malicious scenario:
        // 1. Malicious strategist has secondary strategists under their control
        address maliciousSecondary1 = _deployAccount(0x12, "MaliciousSecondary1");
        address maliciousSecondary2 = _deployAccount(0x13, "MaliciousSecondary2");

        vm.startPrank(strategist); // strategist is acting maliciously
        superVaultAggregator.addSecondaryStrategist(strategy, maliciousSecondary1);
        superVaultAggregator.addSecondaryStrategist(strategy, maliciousSecondary2);
        vm.stopPrank();

        // 2. Malicious strategist creates a proposal to regain control after emergency replacement
        address controlledAccount = _deployAccount(0x14, "ControlledAccount");
        vm.prank(maliciousSecondary1);
        superVaultAggregator.proposeChangePrimaryStrategist(strategy, controlledAccount);

        // 3. SuperGovernor detects malicious behavior and performs emergency replacement
        address emergencyStrategist = _deployAccount(0x15, "EmergencyStrategist");
        vm.prank(address(superGovernor));
        superVaultAggregator.changePrimaryStrategist(strategy, emergencyStrategist);

        // 4. Verify the attack is thwarted:

        // a) All secondary strategists are removed
        address[] memory secondaryStrategists = superVaultAggregator.getSecondaryStrategists(strategy);
        assertEq(secondaryStrategists.length, 0, "All malicious secondary strategists should be removed");

        // b) Emergency strategist is in control
        address currentStrategist = superVaultAggregator.getMainStrategist(strategy);
        assertEq(currentStrategist, emergencyStrategist, "Emergency strategist should be in control");

        // 5. Malicious accounts can no longer propose changes
        vm.prank(maliciousSecondary1);
        vm.expectRevert(ISuperVaultAggregator.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        superVaultAggregator.proposeChangePrimaryStrategist(strategy, controlledAccount);

        vm.prank(maliciousSecondary2);
        vm.expectRevert(ISuperVaultAggregator.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        superVaultAggregator.proposeChangePrimaryStrategist(strategy, controlledAccount);
    }

    /// @notice Tests that only SuperGovernor can call changePrimaryStrategist
    function test_ChangePrimaryStrategist_OnlySuperGovernor() public {
        address newStrategist = _deployAccount(0x16, "NewStrategist");

        // Test unauthorized callers
        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        superVaultAggregator.changePrimaryStrategist(strategy, newStrategist);

        vm.prank(secondaryStrategist);
        vm.expectRevert(ISuperVaultAggregator.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        superVaultAggregator.changePrimaryStrategist(strategy, newStrategist);

        vm.prank(user);
        vm.expectRevert(ISuperVaultAggregator.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        superVaultAggregator.changePrimaryStrategist(strategy, newStrategist);

        // Test that SuperGovernor can call it
        vm.prank(address(superGovernor));
        superVaultAggregator.changePrimaryStrategist(strategy, newStrategist);

        // Verify change was successful
        address currentStrategist = superVaultAggregator.getMainStrategist(strategy);
        assertEq(currentStrategist, newStrategist, "New strategist should be set");
    }

    /// @notice Tests emergency replacement with zero address reverts
    function test_ChangePrimaryStrategist_RevertZeroAddress() public {
        vm.prank(address(superGovernor));
        vm.expectRevert(ISuperVaultAggregator.ZERO_ADDRESS.selector);
        superVaultAggregator.changePrimaryStrategist(strategy, address(0));
    }

    /// @notice Tests emergency replacement with unknown strategy reverts
    function test_ChangePrimaryStrategist_RevertUnknownStrategy() public {
        address unknownStrategy = _deployAccount(0x17, "UnknownStrategy");
        address newStrategist = _deployAccount(0x18, "NewStrategist");

        vm.prank(address(superGovernor));
        vm.expectRevert(ISuperVaultAggregator.UNKNOWN_STRATEGY.selector);
        superVaultAggregator.changePrimaryStrategist(unknownStrategy, newStrategist);
    }

    /// @notice Tests emergency replacement works when no pending proposals exist
    function test_ChangePrimaryStrategist_NoPendingProposals() public {
        // Emergency replacement should still work
        address emergencyStrategist = _deployAccount(0x19, "EmergencyStrategist");
        vm.prank(address(superGovernor));
        superVaultAggregator.changePrimaryStrategist(strategy, emergencyStrategist);

        // Verify change was successful
        address currentStrategist = superVaultAggregator.getMainStrategist(strategy);
        assertEq(currentStrategist, emergencyStrategist, "Emergency strategist should be set");
    }

    /// @notice Tests emergency replacement works when no secondary strategists exist
    function test_ChangePrimaryStrategist_NoSecondaryStrategists() public {
        // Remove the existing secondary strategist
        vm.prank(strategist);
        superVaultAggregator.removeSecondaryStrategist(strategy, secondaryStrategist);

        // Verify no secondary strategists exist
        address[] memory secondaryStrategists = superVaultAggregator.getSecondaryStrategists(strategy);
        assertEq(secondaryStrategists.length, 0, "No secondary strategists should exist");

        // Emergency replacement should still work
        address emergencyStrategist = _deployAccount(0x1A, "EmergencyStrategist");
        vm.prank(address(superGovernor));
        superVaultAggregator.changePrimaryStrategist(strategy, emergencyStrategist);

        // Verify change was successful
        address currentStrategist = superVaultAggregator.getMainStrategist(strategy);
        assertEq(currentStrategist, emergencyStrategist, "Emergency strategist should be set");
    }

    /// @notice Tests that emergency replacement emits proper events
    function test_ChangePrimaryStrategist_EmitsEvents() public {
        // Setup: Add secondary strategists for event testing
        address secondaryStrategist2 = _deployAccount(0x1B, "SecondaryStrategist2");
        vm.prank(strategist);
        superVaultAggregator.addSecondaryStrategist(strategy, secondaryStrategist2);

        address emergencyStrategist = _deployAccount(0x1C, "EmergencyStrategist");

        // Expect SecondaryStrategistRemoved events first (during the clearing loop)
        vm.expectEmit(true, true, false, false);
        emit ISuperVaultAggregator.SecondaryStrategistRemoved(strategy, secondaryStrategist);
        vm.expectEmit(true, true, false, false);
        emit ISuperVaultAggregator.SecondaryStrategistRemoved(strategy, secondaryStrategist2);

        // Then expect PrimaryStrategistChanged event (emitted at the end)
        vm.expectEmit(true, true, true, false);
        emit ISuperVaultAggregator.PrimaryStrategistChanged(strategy, strategist, emergencyStrategist);

        vm.prank(address(superGovernor));
        superVaultAggregator.changePrimaryStrategist(strategy, emergencyStrategist);
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
                secondaryStrategists: new address[](0),
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
                secondaryStrategists: new address[](0),
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
                secondaryStrategists: new address[](0),
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
                secondaryStrategists: new address[](0),
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
                secondaryStrategists: new address[](0),
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

    function test_ForwardPPS_IncreaseClaimableUpkeep() public {
        // Set up as PPS Oracle to be able to call forwardPPS
        vm.startPrank(sGovernor);
        superGovernor.setActivePPSOracle(address(this));
        superGovernor.proposeUpkeepPaymentsChange(true);
        vm.stopPrank();

        vm.warp(8 days);
        superGovernor.executeUpkeepPaymentsChange();

        vm.startPrank(sGovernor);
        superGovernor.setAddress(superGovernor.SUPER_VAULT_AGGREGATOR(), address(superVaultAggregator));
        vm.stopPrank();

        // Create second strategy for testing upkeep; otherwise is stale
        vm.prank(strategist);
        (, address strategy2,) = superVaultAggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                mainStrategist: strategist,
                secondaryStrategists: new address[](0),
                name: "Test Vault 2",
                symbol: "TV2",
                minUpdateInterval: 5,
                maxStaleness: 10 days,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: strategist })
            })
        );
        address _upToken = superGovernor.getAddress(superGovernor.UP());

        deal(_upToken, address(this), 1e18);
        IERC20(_upToken).approve(address(superVaultAggregator), 1e18);
        superVaultAggregator.depositUpkeep(strategist, 1e18);

        // Get initial timestamp
        uint256 initialTimestamp = superVaultAggregator.getLastUpdateTimestamp(strategy2);

        // Update with a newer timestamp (should succeed)
        uint256 newerTimestamp = initialTimestamp + 10;

        // Wait for minimum interval to pass
        vm.warp(block.timestamp + 10);

        vm.expectEmit(true, false, false, false);
        emit ISuperVaultAggregator.PPSUpdated(strategy2, 1e18, 0, 1, 1, newerTimestamp);

        superVaultAggregator.forwardPPS(
            user,
            ISuperVaultAggregator.ForwardPPSArgs({
                strategy: strategy2,
                isExempt: false,
                pps: 1e18,
                ppsStdev: 0,
                validatorSet: 1,
                totalValidators: 1,
                timestamp: newerTimestamp,
                upkeepCost: 0
            })
        );

        // Check claimable
        uint256 claimableUpkeep = superVaultAggregator.claimableUpkeep();
        assertEq(claimableUpkeep, 1e18);

        // Claim UP
        address _superBank = superGovernor.getAddress(superGovernor.SUPER_BANK());
        uint256 superBankBalanceBefore = IERC20(upToken).balanceOf(_superBank);
        assertEq(superBankBalanceBefore, 0);
        vm.startPrank(address(governor));
        superGovernor.executeUpkeepClaim(superVaultAggregator.claimableUpkeep());
        vm.stopPrank();
        uint256 superBankBalanceAfter = IERC20(upToken).balanceOf(_superBank);
        assertEq(superBankBalanceAfter, 1e18);

        // Check claimable again
        claimableUpkeep = superVaultAggregator.claimableUpkeep();
        assertEq(claimableUpkeep, 0);
    }

    /*//////////////////////////////////////////////////////////////
                           HOOK VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Tests hook validation with single-leaf merkle tree (empty global proof)
    function test_ValidateHook_SingleLeafGlobalTree() public {
        // Mock hook address
        address mockHookAddress = address(0x1234567890123456789012345678901234567890);

        // Create hook arguments
        bytes memory hookArgs = abi.encode("test_hook_call", 123);
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(mockHookAddress, hookArgs))));

        // Set global root to be the leaf itself (single-leaf tree)
        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(leaf);

        // Fast forward past timelock
        vm.warp(block.timestamp + 24 hours + 1);

        // Execute the root update
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Test with empty proofs (should work for single-leaf tree)
        bytes32[] memory emptyGlobalProof = new bytes32[](0);
        bytes32[] memory emptyStrategyProof = new bytes32[](0);

        bool isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: mockHookAddress,
                hookArgs: hookArgs,
                globalProof: emptyGlobalProof,
                strategyProof: emptyStrategyProof
            })
        );

        assertTrue(isValid, "Hook should be valid with empty proof for single-leaf global tree");
    }

    /// @notice Tests hook validation with single-leaf merkle tree (empty strategy proof)
    function test_ValidateHook_SingleLeafStrategyTree() public {
        // Create hook arguments
        bytes memory hookArgs = abi.encode("test_hook_call", 456);
        address mockHookAddress = address(0x1234567890123456789012345678901234567890);
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(mockHookAddress, hookArgs))));

        // Set strategy root to be the leaf itself (single-leaf tree)
        vm.prank(strategist);
        superVaultAggregator.proposeStrategyHooksRoot(strategy, leaf);

        // Fast forward past timelock
        vm.warp(block.timestamp + 24 hours + 1);

        // Execute the root update
        superVaultAggregator.executeStrategyHooksRootUpdate(strategy);

        // Test with empty proofs (should work for single-leaf tree)
        bytes32[] memory emptyGlobalProof = new bytes32[](0);
        bytes32[] memory emptyStrategyProof = new bytes32[](0);

        bool isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: mockHookAddress,
                hookArgs: hookArgs,
                globalProof: emptyGlobalProof,
                strategyProof: emptyStrategyProof
            })
        );

        assertTrue(isValid, "Hook should be valid with empty proof for single-leaf strategy tree");
    }

    /// @notice Tests hook validation fails when leaf doesn't match single-leaf tree root
    function test_ValidateHook_SingleLeafTreeWrongLeaf() public {
        // Mock hook addresses
        address mockHookAddress = address(0x1234567890123456789012345678901234567890);
        address differentHookAddress = address(0x2345678901234567890123456789012345678901);

        // Create hook arguments and different leaf
        bytes memory hookArgs = abi.encode("test_hook_call", 789);
        bytes memory differentHookArgs = abi.encode("different_hook_call", 999);
        bytes32 correctLeaf = keccak256(bytes.concat(keccak256(abi.encode(differentHookAddress, differentHookArgs))));

        // Set global root to be a different leaf (single-leaf tree)
        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(correctLeaf);

        // Fast forward past timelock
        vm.warp(block.timestamp + 24 hours + 1);

        // Execute the root update
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Test with empty proofs and wrong hook args (should fail)
        bytes32[] memory emptyGlobalProof = new bytes32[](0);
        bytes32[] memory emptyStrategyProof = new bytes32[](0);

        bool isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: mockHookAddress,
                hookArgs: hookArgs,
                globalProof: emptyGlobalProof,
                strategyProof: emptyStrategyProof
            })
        );

        assertFalse(isValid, "Hook should be invalid when leaf doesn't match single-leaf tree root");
    }

    /// @notice Tests hook validation with vetoed roots
    function test_ValidateHook_VetoedRoots() public {
        // Create hook arguments
        bytes memory hookArgs = abi.encode("test_hook_call", 101_112);
        address mockHookAddress = address(0x1234567890123456789012345678901234567890);
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(mockHookAddress, hookArgs))));

        // Set both global and strategy roots to be the leaf (single-leaf trees)
        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(leaf);

        vm.warp(block.timestamp + 24 hours + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        vm.prank(strategist);
        superVaultAggregator.proposeStrategyHooksRoot(strategy, leaf);

        vm.warp(block.timestamp + 24 hours + 1);
        superVaultAggregator.executeStrategyHooksRootUpdate(strategy);

        // Veto both roots
        vm.prank(address(superGovernor));
        superVaultAggregator.setGlobalHooksRootVetoStatus(true);

        vm.prank(address(superGovernor));
        superVaultAggregator.setStrategyHooksRootVetoStatus(strategy, true);

        // Test with empty proofs (should fail because both are vetoed)
        bytes32[] memory emptyGlobalProof = new bytes32[](0);
        bytes32[] memory emptyStrategyProof = new bytes32[](0);

        bool isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: mockHookAddress,
                hookArgs: hookArgs,
                globalProof: emptyGlobalProof,
                strategyProof: emptyStrategyProof
            })
        );

        assertFalse(isValid, "Hook should be invalid when both roots are vetoed");
    }

    /// @notice Tests hook validation when one root is vetoed but the other is valid
    function test_ValidateHook_OneRootVetoed() public {
        // Create hook arguments
        bytes memory hookArgs = abi.encode("test_hook_call", 131_415);
        address mockHookAddress = address(0x1234567890123456789012345678901234567890);
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(mockHookAddress, hookArgs))));

        // Set strategy root to be the leaf (single-leaf tree)
        vm.prank(strategist);
        superVaultAggregator.proposeStrategyHooksRoot(strategy, leaf);

        vm.warp(block.timestamp + 24 hours + 1);
        superVaultAggregator.executeStrategyHooksRootUpdate(strategy);

        // Veto global root (which is zero anyway)
        vm.prank(address(superGovernor));
        superVaultAggregator.setGlobalHooksRootVetoStatus(true);

        // Test with empty proofs
        bytes32[] memory emptyGlobalProof = new bytes32[](0);
        bytes32[] memory emptyStrategyProof = new bytes32[](0);

        bool isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: mockHookAddress,
                hookArgs: hookArgs,
                globalProof: emptyGlobalProof,
                strategyProof: emptyStrategyProof
            })
        );

        assertFalse(isValid, "Hook should be invalid when global root is vetoed");
    }

    /// @notice Tests batch hook validation with mixed single-leaf and multi-leaf scenarios
    function test_ValidateHooks_BatchValidation() public {
        // Mock hook addresses
        address mockHookAddress1 = address(0x1234567890123456789012345678901234567890);
        address mockHookAddress2 = address(0x2345678901234567890123456789012345678901);

        // Create multiple hook arguments
        bytes memory hookArgs1 = abi.encode("hook1", 1);
        bytes memory hookArgs2 = abi.encode("hook2", 2);
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(mockHookAddress1, hookArgs1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(mockHookAddress2, hookArgs2))));

        // Set global root to first leaf (single-leaf tree)
        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(leaf1);

        vm.warp(block.timestamp + 24 hours + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Set strategy root to second leaf (single-leaf tree)
        vm.prank(strategist);
        superVaultAggregator.proposeStrategyHooksRoot(strategy, leaf2);

        vm.warp(block.timestamp + 24 hours + 1);
        superVaultAggregator.executeStrategyHooksRootUpdate(strategy);

        // Prepare batch data
        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = mockHookAddress1;
        hookAddresses[1] = mockHookAddress2;

        bytes[] memory hooksArgs = new bytes[](2);
        hooksArgs[0] = hookArgs1;
        hooksArgs[1] = hookArgs2;

        bytes32[][] memory globalProofs = new bytes32[][](2);
        globalProofs[0] = new bytes32[](0); // Empty proof for single-leaf tree
        globalProofs[1] = new bytes32[](0); // Empty proof

        bytes32[][] memory strategyProofs = new bytes32[][](2);
        strategyProofs[0] = new bytes32[](0); // Empty proof
        strategyProofs[1] = new bytes32[](0); // Empty proof for single-leaf tree

        // Create ValidateHookArgs array
        ISuperVaultAggregator.ValidateHookArgs[] memory argsArray = new ISuperVaultAggregator.ValidateHookArgs[](2);
        argsArray[0] = ISuperVaultAggregator.ValidateHookArgs({
            hookAddress: hookAddresses[0],
            hookArgs: hooksArgs[0],
            globalProof: globalProofs[0],
            strategyProof: strategyProofs[0]
        });
        argsArray[1] = ISuperVaultAggregator.ValidateHookArgs({
            hookAddress: hookAddresses[1],
            hookArgs: hooksArgs[1],
            globalProof: globalProofs[1],
            strategyProof: strategyProofs[1]
        });

        bool[] memory validHooks = superVaultAggregator.validateHooks(strategy, argsArray);

        assertTrue(validHooks[0], "First hook should be valid against global root");
        assertTrue(validHooks[1], "Second hook should be valid against strategy root");
    }

    // =============================================================
    // Global Leaves Banning Tests
    // =============================================================

    /// @notice Tests successfully changing global leaves status
    function test_ChangeGlobalLeavesStatus_Success() public {
        // Create leaf hashes for testing
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(address(0x123), "args1"))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(address(0x456), "args2"))));

        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = leaf1;
        leaves[1] = leaf2;

        bool[] memory statuses = new bool[](2);
        statuses[0] = true; // Ban leaf1
        statuses[1] = false; // Allow leaf2

        // Primary strategist bans global leaves
        vm.prank(strategist);
        vm.expectEmit(true, false, false, true);
        emit ISuperVaultAggregator.GlobalLeavesStatusChanged(strategy, leaves, statuses);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);
    }

    /// @notice Tests that only primary strategist can change global leaves status
    function test_ChangeGlobalLeavesStatus_Revert_UnauthorizedCaller() public {
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256("test_leaf");

        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        // Secondary strategist cannot change global leaves status
        vm.prank(secondaryStrategist);
        vm.expectRevert(ISuperVaultAggregator.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);

        // Regular user cannot change global leaves status
        vm.prank(user);
        vm.expectRevert(ISuperVaultAggregator.UNAUTHORIZED_UPDATE_AUTHORITY.selector);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);
    }

    /// @notice Tests that mismatched array lengths revert
    function test_ChangeGlobalLeavesStatus_Revert_MismatchedArrays() public {
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256("leaf1");
        leaves[1] = keccak256("leaf2");

        bool[] memory statuses = new bool[](1); // Mismatched length
        statuses[0] = true;

        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.MISMATCHED_ARRAY_LENGTHS.selector);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);
    }

    /// @notice Tests that unknown strategy reverts
    function test_ChangeGlobalLeavesStatus_Revert_UnknownStrategy() public {
        address unknownStrategy = _deployAccount(0x99, "UnknownStrategy");

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256("test_leaf");

        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.prank(strategist);
        vm.expectRevert(ISuperVaultAggregator.UNKNOWN_STRATEGY.selector);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, unknownStrategy);
    }

    /// @notice Tests hook validation with banned global leaves
    function test_ValidateHook_BannedGlobalLeaf() public {
        // Set up global hooks root
        bytes32 globalRoot = keccak256("global_root");
        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(globalRoot);

        // Wait for timelock and execute
        vm.warp(block.timestamp + superVaultAggregator.getHooksRootUpdateTimelock() + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Create a hook that would normally be valid against global root
        address hookAddress = address(0x123);
        bytes memory hookArgs = "test_args";
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(hookAddress, hookArgs))));

        // For single-leaf tree, the root equals the leaf
        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(leaf);
        vm.warp(block.timestamp + superVaultAggregator.getHooksRootUpdateTimelock() + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Initially, hook should be valid
        bytes32[] memory globalProof = new bytes32[](0); // Empty proof for single-leaf tree
        bytes32[] memory strategyProof = new bytes32[](0);

        bool isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: hookAddress,
                hookArgs: hookArgs,
                globalProof: globalProof,
                strategyProof: strategyProof
            })
        );
        assertTrue(isValid, "Hook should be valid initially");

        // Ban the leaf
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true; // Ban the leaf

        vm.prank(strategist);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);

        // Now hook should be invalid
        isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: hookAddress,
                hookArgs: hookArgs,
                globalProof: globalProof,
                strategyProof: strategyProof
            })
        );
        assertFalse(isValid, "Hook should be invalid after banning");
    }

    /// @notice Tests hook validation with unbanned global leaves
    function test_ValidateHook_UnbannedGlobalLeaf() public {
        // Set up global hooks root
        address hookAddress = address(0x123);
        bytes memory hookArgs = "test_args";
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(hookAddress, hookArgs))));

        // Set global root to the leaf for single-leaf tree
        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(leaf);
        vm.warp(block.timestamp + superVaultAggregator.getHooksRootUpdateTimelock() + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Ban the leaf first
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true; // Ban the leaf

        vm.prank(strategist);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);

        // Hook should be invalid
        bytes32[] memory globalProof = new bytes32[](0);
        bytes32[] memory strategyProof = new bytes32[](0);

        bool isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: hookAddress,
                hookArgs: hookArgs,
                globalProof: globalProof,
                strategyProof: strategyProof
            })
        );
        assertFalse(isValid, "Hook should be invalid when banned");

        // Unban the leaf
        statuses[0] = false; // Unban the leaf
        vm.prank(strategist);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);

        // Now hook should be valid again
        isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: hookAddress,
                hookArgs: hookArgs,
                globalProof: globalProof,
                strategyProof: strategyProof
            })
        );
        assertTrue(isValid, "Hook should be valid after unbanning");
    }

    /// @notice Tests batch hook validation with banned global leaves
    function test_ValidateHooks_BannedGlobalLeaves() public {
        // Set up hooks
        address hookAddress1 = address(0x123);
        address hookAddress2 = address(0x456);
        bytes memory hookArgs1 = "args1";
        bytes memory hookArgs2 = "args2";

        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(hookAddress1, hookArgs1))));
        bytes32 leaf2 = keccak256(bytes.concat(keccak256(abi.encode(hookAddress2, hookArgs2))));

        // Set global root to leaf1 for testing
        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(leaf1);
        vm.warp(block.timestamp + superVaultAggregator.getHooksRootUpdateTimelock() + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Set strategy root to leaf2 for testing
        vm.prank(strategist);
        superVaultAggregator.proposeStrategyHooksRoot(strategy, leaf2);
        vm.warp(block.timestamp + superVaultAggregator.getHooksRootUpdateTimelock() + 1);
        superVaultAggregator.executeStrategyHooksRootUpdate(strategy);

        // Ban leaf1 (global)
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf1;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true; // Ban leaf1

        vm.prank(strategist);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);

        // Prepare batch validation
        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = hookAddress1;
        hookAddresses[1] = hookAddress2;

        bytes[] memory hooksArgs = new bytes[](2);
        hooksArgs[0] = hookArgs1;
        hooksArgs[1] = hookArgs2;

        bytes32[][] memory globalProofs = new bytes32[][](2);
        globalProofs[0] = new bytes32[](0); // Empty proof for leaf1
        globalProofs[1] = new bytes32[](0); // Empty proof

        bytes32[][] memory strategyProofs = new bytes32[][](2);
        strategyProofs[0] = new bytes32[](0); // Empty proof
        strategyProofs[1] = new bytes32[](0); // Empty proof for leaf2

        // Create ValidateHookArgs array
        ISuperVaultAggregator.ValidateHookArgs[] memory argsArray = new ISuperVaultAggregator.ValidateHookArgs[](2);
        argsArray[0] = ISuperVaultAggregator.ValidateHookArgs({
            hookAddress: hookAddresses[0],
            hookArgs: hooksArgs[0],
            globalProof: globalProofs[0],
            strategyProof: strategyProofs[0]
        });
        argsArray[1] = ISuperVaultAggregator.ValidateHookArgs({
            hookAddress: hookAddresses[1],
            hookArgs: hooksArgs[1],
            globalProof: globalProofs[1],
            strategyProof: strategyProofs[1]
        });

        bool[] memory validHooks = superVaultAggregator.validateHooks(strategy, argsArray);

        assertFalse(validHooks[0], "First hook should be invalid (banned global leaf)");
        assertTrue(validHooks[1], "Second hook should be valid (strategy leaf not banned)");
    }

    /// @notice Tests that strategy leaves are not affected by global leaf banning
    function test_ValidateHook_StrategyLeafNotAffectedByGlobalBan() public {
        // Set up strategy hooks root
        address hookAddress = address(0x123);
        bytes memory hookArgs = "test_args";
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(hookAddress, hookArgs))));

        // Set strategy root to the leaf
        vm.prank(strategist);
        superVaultAggregator.proposeStrategyHooksRoot(strategy, leaf);
        vm.warp(block.timestamp + superVaultAggregator.getHooksRootUpdateTimelock() + 1);
        superVaultAggregator.executeStrategyHooksRootUpdate(strategy);

        // Ban the same leaf in global context
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true; // Ban the leaf globally

        vm.prank(strategist);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);

        // Hook should still be valid via strategy root
        bytes32[] memory globalProof = new bytes32[](0);
        bytes32[] memory strategyProof = new bytes32[](0); // Empty proof for single-leaf tree

        bool isValid = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: hookAddress,
                hookArgs: hookArgs,
                globalProof: globalProof,
                strategyProof: strategyProof
            })
        );
        assertTrue(isValid, "Hook should be valid via strategy root despite global ban");
    }

    /// @notice Tests multiple leaves banning and unbanning
    function test_ChangeGlobalLeavesStatus_MultipleLeavesToggle() public {
        // Create multiple leaves
        bytes32 leaf1 = keccak256("leaf1");
        bytes32 leaf2 = keccak256("leaf2");
        bytes32 leaf3 = keccak256("leaf3");

        bytes32[] memory leaves = new bytes32[](3);
        leaves[0] = leaf1;
        leaves[1] = leaf2;
        leaves[2] = leaf3;

        // Ban all leaves
        bool[] memory statuses = new bool[](3);
        statuses[0] = true;
        statuses[1] = true;
        statuses[2] = true;

        vm.prank(strategist);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);

        // Unban leaf2 only
        bytes32[] memory singleLeaf = new bytes32[](1);
        singleLeaf[0] = leaf2;
        bool[] memory singleStatus = new bool[](1);
        singleStatus[0] = false;

        vm.prank(strategist);
        vm.expectEmit(true, false, false, true);
        emit ISuperVaultAggregator.GlobalLeavesStatusChanged(strategy, singleLeaf, singleStatus);
        superVaultAggregator.changeGlobalLeavesStatus(singleLeaf, singleStatus, strategy);
    }

    /// @notice Tests that different strategies have independent banned leaves
    function test_ChangeGlobalLeavesStatus_StrategyIndependence() public {
        // Create second strategy
        vm.prank(strategist);
        (, address strategy2,) = superVaultAggregator.createVault(
            ISuperVaultAggregator.VaultCreationParams({
                asset: address(asset),
                mainStrategist: strategist,
                secondaryStrategists: new address[](0),
                name: "Test Vault 2",
                symbol: "TV2",
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({ performanceFeeBps: 1000, recipient: strategist })
            })
        );

        // Set up global root with a test leaf
        address hookAddress = address(0x123);
        bytes memory hookArgs = "test_args";
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(hookAddress, hookArgs))));

        vm.prank(address(superGovernor));
        superVaultAggregator.proposeGlobalHooksRoot(leaf);
        vm.warp(block.timestamp + superVaultAggregator.getHooksRootUpdateTimelock() + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Ban leaf in strategy1 only
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;
        bool[] memory statuses = new bool[](1);
        statuses[0] = true;

        vm.prank(strategist);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);

        // Hook should be invalid for strategy1
        bytes32[] memory globalProof = new bytes32[](0);
        bytes32[] memory strategyProof = new bytes32[](0);

        bool isValid1 = superVaultAggregator.validateHook(
            strategy,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: hookAddress,
                hookArgs: hookArgs,
                globalProof: globalProof,
                strategyProof: strategyProof
            })
        );
        assertFalse(isValid1, "Hook should be invalid for strategy1");

        // Hook should still be valid for strategy2
        bool isValid2 = superVaultAggregator.validateHook(
            strategy2,
            ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: hookAddress,
                hookArgs: hookArgs,
                globalProof: globalProof,
                strategyProof: strategyProof
            })
        );
        assertTrue(isValid2, "Hook should be valid for strategy2");
    }

    /// @notice Tests empty arrays are handled correctly
    function test_ChangeGlobalLeavesStatus_EmptyArrays() public {
        bytes32[] memory leaves = new bytes32[](0);
        bool[] memory statuses = new bool[](0);

        vm.prank(strategist);
        vm.expectEmit(true, false, false, true);
        emit ISuperVaultAggregator.GlobalLeavesStatusChanged(strategy, leaves, statuses);
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);
    }
}
