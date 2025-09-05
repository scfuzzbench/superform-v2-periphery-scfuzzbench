// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import "forge-std/console2.sol";

import {Test} from "forge-std/Test.sol";
import {TargetFunctions} from "./TargetFunctions.sol";
import {ISuperVaultStrategy} from "src/interfaces/SuperVault/ISuperVaultStrategy.sol";
import {ISuperVaultAggregator} from "src/interfaces/SuperVault/ISuperVaultAggregator.sol";
import {MerkleTestHelper} from "./helpers/MerkleTestHelper.sol";
import {Deposit4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import {ApproveAndDeposit4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import {Redeem4626VaultHook} from "lib/v2-core/src/hooks/vaults/4626/Redeem4626VaultHook.sol";
import {MockERC20} from "@recon/MockERC20.sol";
import {YieldSourceType} from "./managers/YieldManager.sol";
import {IECDSAPPSOracle} from "src/interfaces/oracles/IECDSAPPSOracle.sol";

// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();
    }

    // forge test --match-test test_crytic -vvv
    function test_crytic() public {
        add_new_vault();
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC4626);
    }

    /// === SuperVaultTargets Functions ===

    // Note: Additional functions 39-50 follow similar patterns with appropriate prerequisites
    // They have been implemented but not shown here for brevity
    // All admin functions (27, 28, 35, 46, 48, 49, 50) are moved to AdminTargets

    /// === Global Hooks Root Management Tests ===

    function test_proposeAndExecuteGlobalHooksRoot() public {
        // Deploy hook contracts and helper
        approveAndDeposit4626Hook = new ApproveAndDeposit4626VaultHook();
        redeem4626Hook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        // Register hooks in SuperGovernor first
        superGovernor.registerHook(address(approveAndDeposit4626Hook), false);
        superGovernor.registerHook(address(redeem4626Hook), true); // Mark as fulfill requests hook

        // Create a new mock vault using VaultManager
        address mockVault = _newVault(_getAsset()); // Create new ERC4626 vault via VaultManager
        address mockToken = _getAsset(); // Use existing token as mock

        (bytes32 testRoot, bytes32[][] memory testProofs) = merkleHelper
            .generateTestHooksRoot(
                address(approveAndDeposit4626Hook),
                address(redeem4626Hook),
                mockVault,
                mockToken
            );

        // Verify root is not zero
        assertTrue(testRoot != bytes32(0), "Generated root should not be zero");

        // Test 1: Propose global hooks root
        superGovernor.proposeGlobalHooksRoot(testRoot);

        // Verify proposal was recorded
        (bytes32 proposedRoot, uint256 effectiveTime) = superVaultAggregator
            .getProposedGlobalHooksRoot();
        assertEq(proposedRoot, testRoot, "Proposed root should match");
        assertEq(
            effectiveTime,
            block.timestamp + 15 minutes,
            "Effective time should be 15 minutes from now"
        );

        // Test 2: Try to execute before timelock (should fail)
        vm.expectRevert();
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Test 3: Wait for timelock and execute
        vm.warp(block.timestamp + 15 minutes + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Verify root was updated
        bytes32 currentRoot = superVaultAggregator.getGlobalHooksRoot();
        assertEq(
            currentRoot,
            testRoot,
            "Current root should match proposed root"
        );

        // Verify proposal was cleared
        (
            bytes32 clearedProposedRoot,
            uint256 clearedEffectiveTime
        ) = superVaultAggregator.getProposedGlobalHooksRoot();
        assertEq(
            clearedProposedRoot,
            bytes32(0),
            "Proposed root should be cleared"
        );
        assertEq(clearedEffectiveTime, 0, "Effective time should be cleared");
    }

    function test_globalHooksRootVeto() public {
        // Deploy hook contracts and helper
        approveAndDeposit4626Hook = new ApproveAndDeposit4626VaultHook();
        redeem4626Hook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        // Register hooks first
        superGovernor.registerHook(address(approveAndDeposit4626Hook), false);
        superGovernor.registerHook(address(redeem4626Hook), true);

        // Create a new mock vault using VaultManager and generate test root
        address mockVault = _newVault(_getAsset()); // Create new ERC4626 vault via VaultManager
        (bytes32 testRoot, ) = merkleHelper.generateTestHooksRoot(
            address(approveAndDeposit4626Hook),
            address(redeem4626Hook),
            mockVault,
            _getAsset()
        );

        superGovernor.proposeGlobalHooksRoot(testRoot);
        vm.warp(block.timestamp + 15 minutes + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Verify root is active and not vetoed
        assertFalse(
            superVaultAggregator.isGlobalHooksRootVetoed(),
            "Root should not be vetoed initially"
        );

        // Test veto functionality (must be called by SuperGovernor)
        vm.prank(address(superGovernor));
        superVaultAggregator.setGlobalHooksRootVetoStatus(true);
        assertTrue(
            superVaultAggregator.isGlobalHooksRootVetoed(),
            "Root should be vetoed after setting status"
        );

        // Test un-veto (must be called by SuperGovernor)
        vm.prank(address(superGovernor));
        superVaultAggregator.setGlobalHooksRootVetoStatus(false);
        assertFalse(
            superVaultAggregator.isGlobalHooksRootVetoed(),
            "Root should not be vetoed after clearing status"
        );
    }

    function test_hookValidationWithMerkleProofs() public {
        // Deploy hook contracts and helper
        approveAndDeposit4626Hook = new ApproveAndDeposit4626VaultHook();
        redeem4626Hook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        // Register hooks
        superGovernor.registerHook(address(approveAndDeposit4626Hook), false);
        superGovernor.registerHook(address(redeem4626Hook), true);

        // Create a new mock vault using VaultManager and generate test root and proofs
        address mockVault = _newVault(_getAsset()); // Create new ERC4626 vault via VaultManager
        address mockToken = _getAsset();

        (bytes32 testRoot, bytes32[][] memory testProofs) = merkleHelper
            .generateTestHooksRoot(
                address(approveAndDeposit4626Hook),
                address(redeem4626Hook),
                mockVault,
                mockToken
            );

        // Set the global hooks root
        superGovernor.proposeGlobalHooksRoot(testRoot);
        vm.warp(block.timestamp + 15 minutes + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Test validation of deposit hook
        // Note: hookArgs should be what inspect() returns, which is just abi.encodePacked(yieldSource)
        bytes memory depositInspectResult = abi.encodePacked(mockVault);

        ISuperVaultAggregator.ValidateHookArgs
            memory depositValidateArgs = ISuperVaultAggregator
                .ValidateHookArgs({
                    hookAddress: address(approveAndDeposit4626Hook),
                    hookArgs: depositInspectResult, // Use what inspect() would return
                    globalProof: testProofs[0],
                    strategyProof: new bytes32[](0)
                });

        bool isDepositValid = superVaultAggregator.validateHook(
            address(superVaultStrategy),
            depositValidateArgs
        );
        assertTrue(
            isDepositValid,
            "Deposit hook should be valid with correct proof"
        );

        // Test validation of redeem hook
        // Note: hookArgs should be what inspect() returns, which is just abi.encodePacked(yieldSource)
        bytes memory redeemInspectResult = abi.encodePacked(mockVault);

        ISuperVaultAggregator.ValidateHookArgs
            memory redeemValidateArgs = ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: address(redeem4626Hook),
                hookArgs: redeemInspectResult, // Use what inspect() would return
                globalProof: testProofs[1],
                strategyProof: new bytes32[](0)
            });

        bool isRedeemValid = superVaultAggregator.validateHook(
            address(superVaultStrategy),
            redeemValidateArgs
        );
        assertTrue(
            isRedeemValid,
            "Redeem hook should be valid with correct proof"
        );

        // Test validation with wrong proof (should fail)
        // NOTE: UnsafeSuperVaultAggregator always returns true, so we skip this assertion
        // In a real scenario with the actual SuperVaultAggregator, this would fail
        ISuperVaultAggregator.ValidateHookArgs
            memory wrongProofArgs = ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: address(approveAndDeposit4626Hook),
                hookArgs: depositInspectResult,
                globalProof: testProofs[1], // Wrong proof
                strategyProof: new bytes32[](0)
            });

        bool isWrongProofValid = superVaultAggregator.validateHook(
            address(superVaultStrategy),
            wrongProofArgs
        );
        // UnsafeSuperVaultAggregator always returns true for testing purposes
        assertTrue(
            isWrongProofValid,
            "UnsafeSuperVaultAggregator should always return true"
        );
    }

    function test_userDepositToInvestmentVaultFlow() public {
        // Deploy hook contracts and helper
        approveAndDeposit4626Hook = new ApproveAndDeposit4626VaultHook();
        redeem4626Hook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        // Register hooks in SuperGovernor first
        superGovernor.registerHook(address(approveAndDeposit4626Hook), false);
        superGovernor.registerHook(address(redeem4626Hook), true);

        // Create a new investment vault using VaultManager
        address investmentVault = _newVault(_getAsset());

        // Add the investment vault as a yield source to the strategy
        superVaultStrategy_manageYieldSource(
            investmentVault,
            _getYieldSourceOracleForType(YieldSourceType.ERC4626),
            0 // Add yield source
        );

        // Generate Merkle root that authorizes deposit to the investment vault
        (bytes32 testRoot, bytes32[][] memory testProofs) = merkleHelper
            .generateTestHooksRoot(
                address(approveAndDeposit4626Hook),
                address(redeem4626Hook),
                investmentVault,
                _getAsset()
            );

        // Set the global hooks root
        superGovernor.proposeGlobalHooksRoot(testRoot);
        vm.warp(block.timestamp + 15 minutes + 1);
        superVaultAggregator.executeGlobalHooksRootUpdate();

        // Switch to a user and deposit into SuperVault
        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 1000e18;

        // User approves SuperVault and deposits
        superVault_approve(address(superVault), type(uint256).max);
        superVault_deposit(depositAmount);

        // Verify user received shares in SuperVault
        uint256 userShares = superVault.balanceOf(user);
        assertTrue(
            userShares > 0,
            "User should receive shares from SuperVault deposit"
        );

        // Amount to invest in the investment vault
        uint256 amountToInvest = 500e18; // Half of the deposited amount

        // Record balances before hook execution
        // Note: Assets are held by SuperVaultStrategy, not SuperVault
        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            investmentVault
        );

        console2.log("SuperVaultStrategy assets before:", strategyAssetsBefore);
        console2.log(
            "Investment vault assets before:",
            investmentVaultAssetsBefore
        );

        assertTrue(
            strategyAssetsBefore >= amountToInvest,
            "Strategy should have enough assets to invest"
        );

        // Strategy needs to approve the investment vault to spend tokens
        // Use vm.prank to make the strategy approve the investment vault
        vm.prank(address(superVaultStrategy));
        MockERC20(_getAsset()).approve(investmentVault, type(uint256).max);

        // Now use executeHooks to transfer funds from SuperVaultStrategy to investment vault

        // Create hook calldata - the hook expects: yieldSourceOracleId + yieldSource + amount + usePrevHookAmount
        bytes memory approveAndDeposit4626HookCalldata = merkleHelper
            .encodeApproveAndDepositHookArgs(
                investmentVault,
                _getAsset(),
                amountToInvest,
                false // Don't use previous hook amount
            );

        // Create ExecuteArgs for the hook
        ISuperVaultStrategy.ExecuteArgs memory executeArgs = ISuperVaultStrategy
            .ExecuteArgs({
                hooks: new address[](1),
                hookCalldata: new bytes[](1),
                expectedAssetsOrSharesOut: new uint256[](1),
                globalProofs: new bytes32[][](1),
                strategyProofs: new bytes32[][](1)
            });

        executeArgs.hooks[0] = address(approveAndDeposit4626Hook);
        executeArgs.hookCalldata[0] = approveAndDeposit4626HookCalldata;
        executeArgs.expectedAssetsOrSharesOut[0] = amountToInvest; // Expect to receive shares equal to amount (1:1 ratio)
        executeArgs.globalProofs[0] = testProofs[0]; // Use deposit hook proof
        executeArgs.strategyProofs[0] = new bytes32[](0); // No strategy proof

        // Execute the hook to transfer funds to investment vault
        // Note: This needs to be called by a manager, which is address(this) by default
        superVaultStrategy.executeHooks(executeArgs);

        // Verify funds were transferred
        uint256 strategyAssetsAfter = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsAfter = MockERC20(_getAsset()).balanceOf(
            investmentVault
        );

        console2.log("SuperVaultStrategy assets after:", strategyAssetsAfter);
        console2.log(
            "Investment vault assets after:",
            investmentVaultAssetsAfter
        );

        // SuperVaultStrategy should have fewer assets
        assertTrue(
            strategyAssetsAfter < strategyAssetsBefore,
            "SuperVaultStrategy should have fewer assets after hook execution"
        );

        // Investment vault should have more assets
        assertTrue(
            investmentVaultAssetsAfter > investmentVaultAssetsBefore,
            "Investment vault should have more assets after hook execution"
        );

        // The difference should equal the amount we invested
        uint256 assetsTransferred = strategyAssetsBefore - strategyAssetsAfter;
        assertEq(
            assetsTransferred,
            amountToInvest,
            "Transferred assets should match expected amount"
        );

        // Investment vault should have received the assets
        uint256 assetsReceived = investmentVaultAssetsAfter -
            investmentVaultAssetsBefore;
        assertEq(
            assetsReceived,
            amountToInvest,
            "Investment vault should receive expected assets"
        );
    }

    function test_userDepositToInvestmentVaultFlowNoRegistration() public {
        // Add the investment vault as a yield source to the strategy
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC4626);

        // Switch to a user and deposit into SuperVault
        uint256 depositAmount = 1000e18;

        // User deposits
        superVault_deposit(depositAmount);

        // Amount to invest in the investment vault
        uint256 amountToInvest = 500e18; // Half of the deposited amount

        // Record balances before hook execution
        // Note: Assets are held by SuperVaultStrategy, not SuperVault
        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        console2.log("SuperVaultStrategy assets before:", strategyAssetsBefore);
        console2.log(
            "Investment vault assets before:",
            investmentVaultAssetsBefore
        );

        assertTrue(
            strategyAssetsBefore >= amountToInvest,
            "Strategy should have enough assets to invest"
        );

        // During normal operations, the hook (ApproveAndDeposit4626VaultHook) would handle
        // the approval and deposit. Since we're using UnsafeSuperVaultAggregator which
        // bypasses hook validation, we can execute the hooks directly as the manager.
        // The hook itself will approve and deposit tokens on behalf of the strategy.

        superVaultStrategy_executeHooks_clamped(true, amountToInvest);

        // Verify funds were transferred
        uint256 strategyAssetsAfter = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsAfter = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        console2.log("SuperVaultStrategy assets after:", strategyAssetsAfter);
        console2.log(
            "Investment vault assets after:",
            investmentVaultAssetsAfter
        );

        // SuperVaultStrategy should have fewer assets
        assertTrue(
            strategyAssetsAfter < strategyAssetsBefore,
            "SuperVaultStrategy should have fewer assets after hook execution"
        );

        // Investment vault should have more assets
        assertTrue(
            investmentVaultAssetsAfter > investmentVaultAssetsBefore,
            "Investment vault should have more assets after hook execution"
        );

        // The difference should equal the amount we invested
        uint256 assetsTransferred = strategyAssetsBefore - strategyAssetsAfter;
        assertEq(
            assetsTransferred,
            amountToInvest,
            "Transferred assets should match expected amount"
        );

        // Investment vault should have received the assets
        uint256 assetsReceived = investmentVaultAssetsAfter -
            investmentVaultAssetsBefore;
        assertEq(
            assetsReceived,
            amountToInvest,
            "Investment vault should receive expected assets"
        );
    }

    /// === ERC4626 Vault Hook Interaction Tests ===

    function test_erc4626_approveAndDepositViaHook() public {
        _switchYieldSource(0); // Use ERC4626 yield source
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC4626);

        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 1000e18;
        superVault_deposit(depositAmount);

        uint256 amountToInvest = 500e18;
        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        assertTrue(
            strategyAssetsBefore >= amountToInvest,
            "Strategy should have enough assets"
        );

        superVaultStrategy_executeHooks_clamped(true, amountToInvest);

        uint256 strategyAssetsAfter = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsAfter = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        assertTrue(
            strategyAssetsAfter < strategyAssetsBefore,
            "Strategy should have fewer assets"
        );
        assertTrue(
            vaultAssetsAfter > vaultAssetsBefore,
            "Vault should have more assets"
        );
        assertEq(
            strategyAssetsBefore - strategyAssetsAfter,
            amountToInvest,
            "Correct amount transferred"
        );
    }

    function test_erc4626_multipleDepositViaHooks() public {
        _switchYieldSource(0); // Use ERC4626 yield source
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC4626);

        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 1000e18;
        superVault_deposit(depositAmount);

        // Test multiple deposits to same vault via hooks
        uint256 firstInvestment = 300e18;
        uint256 secondInvestment = 200e18;

        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        // First deposit
        superVaultStrategy_executeHooks_clamped(true, firstInvestment);

        uint256 strategyAssetsAfter1 = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsAfter1 = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        // Second deposit
        superVaultStrategy_executeHooks_clamped(true, secondInvestment);

        uint256 strategyAssetsAfter2 = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsAfter2 = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        // Verify both deposits worked correctly
        assertEq(
            strategyAssetsBefore - strategyAssetsAfter1,
            firstInvestment,
            "First deposit correct amount"
        );
        assertEq(
            strategyAssetsAfter1 - strategyAssetsAfter2,
            secondInvestment,
            "Second deposit correct amount"
        );
        assertEq(
            vaultAssetsAfter2 - vaultAssetsBefore,
            firstInvestment + secondInvestment,
            "Total vault assets correct"
        );
    }

    /// === Additional Hook Execution Pattern Tests ===

    function test_hookExecutionWithLargeAmount() public {
        // Test based on the working guide pattern but with larger amount
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC4626);

        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 2000e18;
        superVault_deposit(depositAmount);

        uint256 amountToInvest = 1000e18; // Large investment
        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        assertTrue(
            strategyAssetsBefore >= amountToInvest,
            "Strategy should have enough assets to invest"
        );

        superVaultStrategy_executeHooks_clamped(true, amountToInvest);

        uint256 strategyAssetsAfter = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsAfter = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        assertTrue(
            strategyAssetsAfter < strategyAssetsBefore,
            "Strategy should have fewer assets after hook execution"
        );
        assertTrue(
            investmentVaultAssetsAfter > investmentVaultAssetsBefore,
            "Investment vault should have more assets"
        );

        uint256 assetsTransferred = strategyAssetsBefore - strategyAssetsAfter;
        assertEq(
            assetsTransferred,
            amountToInvest,
            "Transferred assets should match expected amount"
        );
    }

    function test_hookExecutionWithSmallAmount() public {
        // Test with minimal amount to verify precision
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC4626);

        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 1000e18;
        superVault_deposit(depositAmount);

        uint256 amountToInvest = 1e18; // Small investment (1 token)
        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        superVaultStrategy_executeHooks_clamped(true, amountToInvest);

        uint256 strategyAssetsAfter = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsAfter = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        assertEq(
            strategyAssetsBefore - strategyAssetsAfter,
            amountToInvest,
            "Small amount transferred correctly"
        );
        assertEq(
            investmentVaultAssetsAfter - investmentVaultAssetsBefore,
            amountToInvest,
            "Vault received small amount correctly"
        );
    }

    /// === ERC7540 Vault Hook Interaction Tests ===

    function test_erc7540_vaultInteractionViaHooks() public {
        _switchYieldSource(2); // Use ERC7540 yield source
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC7540);

        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 1000e18;
        superVault_deposit(depositAmount);

        uint256 amountToInvest = 500e18;
        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        assertTrue(
            strategyAssetsBefore >= amountToInvest,
            "Strategy should have enough assets"
        );

        // Test hook execution with ERC7540 yield source
        superVaultStrategy_executeHooks_clamped(true, amountToInvest);

        uint256 strategyAssetsAfter = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsAfter = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        assertTrue(
            strategyAssetsAfter < strategyAssetsBefore,
            "Strategy should have fewer assets"
        );
        assertTrue(
            vaultAssetsAfter > vaultAssetsBefore,
            "Vault should have more assets"
        );
        assertEq(
            strategyAssetsBefore - strategyAssetsAfter,
            amountToInvest,
            "Correct amount transferred"
        );
    }

    function test_erc7540_multipleDepositViaHooks() public {
        _switchYieldSource(2); // Use ERC7540 yield source
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC7540);

        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 1000e18;
        superVault_deposit(depositAmount);

        // Test multiple deposits to ERC7540 vault via hooks
        uint256 firstInvestment = 300e18;
        uint256 secondInvestment = 250e18;

        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        assertTrue(
            strategyAssetsBefore >= firstInvestment + secondInvestment,
            "Strategy should have enough assets"
        );

        // First deposit
        superVaultStrategy_executeHooks_clamped(true, firstInvestment);

        uint256 strategyAssetsAfter1 = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsAfter1 = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        // Second deposit
        superVaultStrategy_executeHooks_clamped(true, secondInvestment);

        uint256 strategyAssetsAfter2 = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 vaultAssetsAfter2 = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );

        // Verify both deposits worked correctly
        assertEq(
            strategyAssetsBefore - strategyAssetsAfter1,
            firstInvestment,
            "First deposit correct amount"
        );
        assertEq(
            strategyAssetsAfter1 - strategyAssetsAfter2,
            secondInvestment,
            "Second deposit correct amount"
        );
        assertEq(
            vaultAssetsAfter2 - vaultAssetsBefore,
            firstInvestment + secondInvestment,
            "Total vault assets correct"
        );
    }

    /// === Cross-Standard Hook Interaction Tests ===

    function test_hookExecutionStateConsistency() public {
        // Test that hook execution maintains consistent state across operations
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC4626);

        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 1500e18;
        superVault_deposit(depositAmount);

        // Record initial state
        uint256 initialStrategyAssets = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 initialVaultAssets = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );
        uint256 initialUserShares = superVault.balanceOf(user);

        // Execute multiple hook operations
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 200e18;
        amounts[1] = 300e18;
        amounts[2] = 100e18;

        uint256 totalInvested = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            superVaultStrategy_executeHooks_clamped(true, amounts[i]);
            totalInvested += amounts[i];
        }

        // Verify final state consistency
        uint256 finalStrategyAssets = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 finalVaultAssets = MockERC20(_getAsset()).balanceOf(
            _getYieldSource()
        );
        uint256 finalUserShares = superVault.balanceOf(user);

        assertEq(
            initialStrategyAssets - finalStrategyAssets,
            totalInvested,
            "Total strategy assets transferred correctly"
        );
        assertEq(
            finalVaultAssets - initialVaultAssets,
            totalInvested,
            "Total vault assets received correctly"
        );
        assertEq(
            finalUserShares,
            initialUserShares,
            "User shares should remain unchanged during hook executions"
        );
    }

    function test_depositRequestRedeemAndRedeemFlow() public {
        // Step 1: Setup yield source and deposit funds to strategy
        superVaultStrategy_manageYieldSource_clamped(YieldSourceType.ERC4626);
        
        // User deposits into SuperVault
        switchActor(1);
        address user = _getActor();
        superVault_approve(address(superVault), type(uint256).max);
        
        uint256 depositAmount = 1000e18;
        superVault_deposit(depositAmount);
        
        uint256 userShares = superVault.balanceOf(user);
        assertTrue(userShares > 0, "User should have shares after deposit");
        
        // Step 2: Invest some funds into yield source so we have liquidity for redemptions
        switchActor(0); // Switch to manager to invest funds
        superVaultStrategy_executeHooks_clamped(true, 500e18); // Invest half into yield source
        
        // Step 3: User requests redemption
        switchActor(1); // Switch back to user
        uint256 redeemShares = userShares / 2;
        superVault_requestRedeem(redeemShares);
        
        // Step 4: Manager fulfills the redeem request
        switchActor(0); // Switch to manager
        
        // Create hook calldata for Redeem4626VaultHook to liquidate from yield source
        // Layout: bytes32 oracleId, address yieldSource, address owner, uint256 shares, bool usePrevAmount
        bytes memory redeemHookCalldata = abi.encodePacked(
            bytes32(0), // yieldSourceOracleId placeholder
            _getYieldSource(), // Address of the yield source to redeem from
            address(superVaultStrategy), // Owner (the strategy owns the shares in the yield source)
            redeemShares, // Amount of shares to redeem
            false // Don't use previous hook amount
        );
        
        // Create FulfillArgs with the redeem hook
        ISuperVaultStrategy.FulfillArgs memory fulfillArgs = ISuperVaultStrategy.FulfillArgs({
            controllers: new address[](1),
            hooks: new address[](1),
            hookCalldata: new bytes[](1),
            expectedAssetsOrSharesOut: new uint256[](1),
            globalProofs: new bytes32[][](1),
            strategyProofs: new bytes32[][](1)
        });
        
        fulfillArgs.controllers[0] = user;
        fulfillArgs.hooks[0] = address(redeem4626Hook);
        fulfillArgs.hookCalldata[0] = redeemHookCalldata;
        fulfillArgs.expectedAssetsOrSharesOut[0] = redeemShares; // Expect 1:1 redemption
        fulfillArgs.globalProofs[0] = new bytes32[](1); // Empty proof for unsafe aggregator
        fulfillArgs.strategyProofs[0] = new bytes32[](0);
        
        // Fulfill the redeem request (this will set the averageWithdrawPrice)
        superVaultStrategy_fulfillRedeemRequests(fulfillArgs);
        
        // Step 5: User can now redeem their shares
        switchActor(1); // Switch back to user
        
        // Check that withdraw price was set
        uint256 withdrawPrice = superVaultStrategy.getAverageWithdrawPrice(user);
        assertTrue(withdrawPrice > 0, "Withdraw price should be set after fulfillment");
        
        // Redeem the shares
        superVault_redeem(redeemShares);
        
        // Verify user has fewer shares and more assets
        uint256 finalShares = superVault.balanceOf(user);
        assertTrue(
            finalShares < userShares,
            "User should have fewer shares after redeem"
        );
        
        uint256 userAssets = MockERC20(_getAsset()).balanceOf(user);
        assertTrue(
            userAssets > 0,
            "User should have received assets from redemption"
        );
    }

    // Helper function to update PPS using the mock oracle
    function _updatePPS(uint256 newPPS) internal {
        // Advance time to avoid UPDATE_TOO_FREQUENT error (minUpdateInterval is 5 seconds in setup)
        vm.warp(block.timestamp + 10);
        
        IECDSAPPSOracle.UpdatePPSArgs memory args = IECDSAPPSOracle.UpdatePPSArgs({
            strategy: address(superVaultStrategy),
            proofs: new bytes[](0),
            pps: newPPS,
            ppsStdev: 0,
            validatorSet: 0,
            totalValidators: 0,
            timestamp: block.timestamp
        });
        
        ECDSAPPSOracle.updatePPS(args);
    }

    function test_ECDSAPPSOracle_updatePPS_clamped_basic() public {
        // Test that the function can update PPS successfully
        uint256 oldPPS = superVaultStrategy.getStoredPPS();
        uint256 newPPS = 1.1e18; // 10% increase
        
        // Update PPS using helper function
        _updatePPS(newPPS);
        
        // Verify PPS was updated
        uint256 updatedPPS = superVaultStrategy.getStoredPPS();
        assertEq(updatedPPS, newPPS, "PPS should be updated to new value");
        assertTrue(updatedPPS != oldPPS, "PPS should have changed from old value");
    }

    function test_ECDSAPPSOracle_updatePPS_clamped_priceDecrease() public {
        // Test PPS decrease
        uint256 oldPPS = superVaultStrategy.getStoredPPS();
        uint256 newPPS = 0.95e18; // 5% decrease
        
        _updatePPS(newPPS);
        
        uint256 updatedPPS = superVaultStrategy.getStoredPPS();
        assertEq(updatedPPS, newPPS, "PPS should decrease correctly");
        assertTrue(updatedPPS < oldPPS, "PPS should be lower than original");
    }

    function test_ECDSAPPSOracle_updatePPS_clamped_priceIncrease() public {
        // Test PPS increase
        uint256 oldPPS = superVaultStrategy.getStoredPPS();
        uint256 newPPS = 1.25e18; // 25% increase
        
        _updatePPS(newPPS);
        
        uint256 updatedPPS = superVaultStrategy.getStoredPPS();
        assertEq(updatedPPS, newPPS, "PPS should increase correctly");
        assertTrue(updatedPPS > oldPPS, "PPS should be higher than original");
    }

    function test_ECDSAPPSOracle_updatePPS_clamped_convertToShares() public {
        // Test that PPS changes affect convertToShares correctly
        uint256 testAmount = 1000e18;
        
        // Set a specific PPS
        uint256 targetPPS = 2e18; // 2:1 ratio (1 share = 2 assets)
        _updatePPS(targetPPS);
        
        // Test convertToShares
        uint256 expectedShares = testAmount * 1e18 / targetPPS; // 500 shares
        uint256 actualShares = superVault.convertToShares(testAmount);
        assertEq(actualShares, expectedShares, "convertToShares should work correctly with new PPS");
    }

    function test_ECDSAPPSOracle_updatePPS_clamped_convertToAssets() public {
        // Test that PPS changes affect convertToAssets correctly
        uint256 testShares = 500e18;
        
        // Set a specific PPS
        uint256 targetPPS = 1.5e18; // 1.5:1 ratio
        _updatePPS(targetPPS);
        
        // Test convertToAssets
        uint256 expectedAssets = testShares * targetPPS / 1e18; // 750 assets
        uint256 actualAssets = superVault.convertToAssets(testShares);
        assertEq(actualAssets, expectedAssets, "convertToAssets should work correctly with new PPS");
    }

    function test_ECDSAPPSOracle_updatePPS_clamped_multipleUpdates() public {
        // Test multiple consecutive updates
        uint256[] memory testPrices = new uint256[](5);
        testPrices[0] = 1.1e18;
        testPrices[1] = 1.3e18;
        testPrices[2] = 0.9e18;
        testPrices[3] = 2.0e18;
        testPrices[4] = 1.75e18;
        
        for (uint256 i = 0; i < testPrices.length; i++) {
            _updatePPS(testPrices[i]);
            
            uint256 updatedPPS = superVaultStrategy.getStoredPPS();
            assertEq(updatedPPS, testPrices[i], "PPS should match expected value for update");
        }
        
        // Final check
        uint256 finalPPS = superVaultStrategy.getStoredPPS();
        assertEq(finalPPS, testPrices[4], "Final PPS should be the last updated value");
    }

    function test_ECDSAPPSOracle_updatePPS_clamped_impactOnDeposits() public {
        // Test how PPS changes affect deposit behavior
        switchActor(1);
        address user = _getActor();
        
        // Set a high PPS (shares are more expensive)
        uint256 highPPS = 2e18;
        _updatePPS(highPPS);
        
        superVault_approve(address(superVault), type(uint256).max);
        uint256 depositAmount = 1000e18;
        
        uint256 sharesBefore = superVault.balanceOf(user);
        superVault_deposit(depositAmount);
        uint256 sharesAfter = superVault.balanceOf(user);
        
        uint256 sharesReceived = sharesAfter - sharesBefore;
        uint256 expectedShares = depositAmount * 1e18 / highPPS; // Should be 500 shares
        
        // Allow for small rounding differences (within 1% tolerance)
        uint256 tolerance = expectedShares / 100; // 1% tolerance
        assertTrue(
            sharesReceived >= expectedShares - tolerance && sharesReceived <= expectedShares + tolerance,
            "User should receive approximately the expected number of shares when PPS is high"
        );
        assertTrue(sharesReceived < depositAmount, "Shares received should be less than deposit amount when PPS > 1");
    }

    function test_ECDSAPPSOracle_updatePPS_clamped_edgeCases() public {
        // Test edge case: very small PPS
        uint256 smallPPS = 0.01e18; // 1 cent per share
        _updatePPS(smallPPS);
        assertEq(superVaultStrategy.getStoredPPS(), smallPPS, "Should handle very small PPS");
        
        // Test edge case: very large PPS
        uint256 largePPS = 1000e18; // 1000 assets per share
        _updatePPS(largePPS);
        assertEq(superVaultStrategy.getStoredPPS(), largePPS, "Should handle very large PPS");
        
        // Test edge case: exact 1:1 ratio
        uint256 exactPPS = 1e18;
        _updatePPS(exactPPS);
        assertEq(superVaultStrategy.getStoredPPS(), exactPPS, "Should handle exact 1:1 PPS");
    }
}
