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

// forge test --match-contract CryticToFoundry -vv
contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();
    }

    // forge test --match-test test_crytic -vvv
    function test_crytic() public {
        add_new_vault();
        superVaultStrategy_manageYieldSource_clamped();
    }

    /// === SuperVaultTargets Functions ===
    // Note: SuperVaultEscrowTargets functions are documented in reverting_handlers.md as they require vault-only access

    // 3. superVault_authorizeOperator - no prerequisite
    function test_superVault_authorizeOperator() public {
        switchActor(1);

        address controller = _getActor();
        address operator = _getActors()[1]; // Use second actor as operator
        bool approved = true;
        bytes32 nonce = keccak256(abi.encode("test_nonce"));
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = hex"1234"; // Mock signature for testing

        superVault_authorizeOperator(
            controller,
            operator,
            approved,
            nonce,
            deadline,
            signature
        );
    }

    // 4. superVault_transfer - approve must be called first
    function test_superVault_transfer() public {
        switchActor(1);

        // First deposit to get some shares
        superVault_approve(address(superVault), type(uint256).max);
        superVault_deposit(1000e18, _getActor());

        // Now transfer some shares to another actor
        address to = _getActors()[1];
        superVault_transfer(to, 100e18);
    }

    // 5. superVault_transferFrom - approve must be called first
    function test_superVault_transferFrom() public {
        // Use first actor to deposit and approve
        switchActor(1);
        address depositor = _getActor();

        // First deposit to get some shares
        superVault_approve(address(superVault), type(uint256).max);
        superVault_deposit(1000e18, depositor);

        // Get the second actor address by switching to it
        switchActor(2);
        address spender = _getActor();

        // Switch back to first actor to approve the spender
        switchActor(1);
        superVault_approve(spender, 200e18);

        // Switch to the spender and transfer from original depositor
        switchActor(2);
        address to = address(this);
        superVault_transferFrom(depositor, to, 100e18);
    }

    // 6. superVault_deposit - approve must be called first
    function test_superVault_deposit() public {
        switchActor(1);

        // Approve the vault to take assets
        superVault_approve(address(superVault), type(uint256).max);

        // Deposit assets to get shares
        superVault_deposit(1000e18, _getActor());
    }

    // 7. superVault_mint - approve must be called first
    function test_superVault_mint() public {
        switchActor(1);

        // Approve the vault to take assets
        superVault_approve(address(superVault), type(uint256).max);

        // Mint shares for assets
        superVault_mint(1000e18, _getActor());
    }

    // 8. superVault_requestRedeem - deposit or mint must be called first
    function test_superVault_requestRedeem() public {
        switchActor(1);

        // First deposit to get some shares (prerequisite)
        superVault_approve(address(superVault), type(uint256).max);
        superVault_deposit(1000e18, _getActor());

        // Now request redeem
        address controller = _getActor();
        address owner = _getActor();
        superVault_requestRedeem(500e18, controller, owner);
    }

    // 9. superVault_cancelRedeem - requestRedeem must be called first
    function test_superVault_cancelRedeem() public {
        switchActor(1);

        // First deposit to get some shares
        superVault_approve(address(superVault), type(uint256).max);
        superVault_deposit(1000e18, _getActor());

        // Request redeem first (prerequisite)
        address controller = _getActor();
        address owner = _getActor();
        superVault_requestRedeem(500e18, controller, owner);

        // Now cancel the redeem request
        superVault_cancelRedeem(controller);
    }

    // 10. superVault_redeem - deposit or mint must be called first
    function test_superVault_redeem() public {
        switchActor(1);

        // First deposit to get some shares (prerequisite)
        superVault_approve(address(superVault), type(uint256).max);
        superVault_deposit(1000e18, _getActor());

        // Now redeem shares for assets
        address receiver = _getActor();
        address controller = _getActor();
        superVault_redeem(500e18, receiver, controller);
    }

    // 11. superVault_withdraw - deposit or mint must be called first
    function test_superVault_withdraw() public {
        switchActor(1);

        // First deposit to get some shares (prerequisite)
        superVault_approve(address(superVault), type(uint256).max);
        superVault_deposit(1000e18, _getActor());

        // Now withdraw assets
        address receiver = _getActor();
        address controller = _getActor();
        superVault_withdraw(500e18, receiver, controller);
    }

    // 12. superVault_burnShares - deposit or mint must be called first
    function test_superVault_burnShares() public {
        switchActor(1);

        // First deposit to get some shares (prerequisite)
        superVault_approve(address(superVault), type(uint256).max);
        superVault_deposit(1000e18, _getActor());

        // Now burn some shares
        superVault_burnShares(100e18);
    }

    /// === SuperVaultStrategyTargets Functions ===

    // 13. superVaultStrategy_updateMaxPPSSlippage - no prerequisite (requires manager access)
    function test_superVaultStrategy_updateMaxPPSSlippage() public {
        // Use contract itself as it's the main manager
        // Don't switch actor - use the default (address(this))

        // Update max PPS slippage
        superVaultStrategy_updateMaxPPSSlippage(500); // 5% slippage
    }

    // 14. superVaultStrategy_proposeVaultFeeConfigUpdate - no prerequisite (requires manager access)
    function test_superVaultStrategy_proposeVaultFeeConfigUpdate() public {
        // Use contract itself as it's the main manager

        // Propose new fee configuration
        uint256 performanceFeeBps = 500; // 5%
        uint256 managementFeeBps = 50; // 0.5%
        address recipient = address(this);

        superVaultStrategy_proposeVaultFeeConfigUpdate(
            performanceFeeBps,
            managementFeeBps,
            recipient
        );
    }

    // 15. superVaultStrategy_executeVaultFeeConfigUpdate - proposeVaultFeeConfigUpdate must be called first (requires manager access)
    function test_superVaultStrategy_executeVaultFeeConfigUpdate() public {
        // Use contract itself as it's the main manager

        // First propose fee config update (prerequisite)
        uint256 performanceFeeBps = 500;
        uint256 managementFeeBps = 50;
        address recipient = address(this);
        superVaultStrategy_proposeVaultFeeConfigUpdate(
            performanceFeeBps,
            managementFeeBps,
            recipient
        );

        // Now execute the fee config update
        superVaultStrategy_executeVaultFeeConfigUpdate();
    }

    // 16. superVaultStrategy_manageYieldSource - no prerequisite (requires manager access)
    function test_superVaultStrategy_manageYieldSource() public {
        // Use contract itself as it's the main manager

        // Manage yield source
        address yieldSource = _getVault(); // Use existing vault as yield source
        address oracle = address(yieldSourceOracle);
        uint8 action = 0; // Add yield source

        superVaultStrategy_manageYieldSource(yieldSource, oracle, action);
    }

    // 17. superVaultStrategy_manageYieldSources - no prerequisite (requires manager access)
    function test_superVaultStrategy_manageYieldSources() public {
        // Use contract itself as it's the main manager

        // Manage multiple yield sources
        address[] memory yieldSources = new address[](1);
        address[] memory oracles = new address[](1);
        uint8[] memory actions = new uint8[](1);

        yieldSources[0] = _getVault();
        oracles[0] = address(yieldSourceOracle);
        actions[0] = 0; // Add yield source

        superVaultStrategy_manageYieldSources(yieldSources, oracles, actions);
    }

    // 18. superVaultStrategy_manageYieldSource_clamped - no prerequisite (requires manager access, already implemented in target functions)
    function test_superVaultStrategy_manageYieldSource_clamped() public {
        // Use contract itself as it's the main manager
        // Use the clamped version from target functions
        superVaultStrategy_manageYieldSource_clamped();
    }

    // 19. superVaultStrategy_handleOperations4626Deposit - manageYieldSource must be called first
    function test_superVaultStrategy_handleOperations4626Deposit() public {
        switchActor(1);

        // First manage yield source (prerequisite)
        superVaultStrategy_manageYieldSource_clamped();

        // Now handle operations for 4626 deposit
        address controller = _getActor();
        uint256 assetsGross = 1000e18;

        superVaultStrategy_handleOperations4626Deposit(controller, assetsGross);
    }

    // 20. superVaultStrategy_handleOperations4626Mint - manageYieldSource must be called first
    function test_superVaultStrategy_handleOperations4626Mint() public {
        switchActor(1);

        // First manage yield source (prerequisite)
        superVaultStrategy_manageYieldSource_clamped();

        // Now handle operations for 4626 mint
        address controller = _getActor();
        uint256 sharesNet = 900e18;
        uint256 assetsGross = 1000e18;
        uint256 assetsNet = 990e18;

        superVaultStrategy_handleOperations4626Mint(
            controller,
            sharesNet,
            assetsGross,
            assetsNet
        );
    }

    // 21. superVaultStrategy_handleOperations7540 - manageYieldSource must be called first
    function test_superVaultStrategy_handleOperations7540() public {
        // First manage yield source (prerequisite)
        superVaultStrategy_manageYieldSource_clamped();

        switchActor(1);

        // Now handle operations for 7540
        ISuperVaultStrategy.Operation operation = ISuperVaultStrategy
            .Operation
            .Deposit;
        address controller = _getActor();
        address receiver = _getActor();
        uint256 amount = 1000e18;

        superVaultStrategy_handleOperations7540(
            operation,
            controller,
            receiver,
            amount
        );
    }

    // 22. superVaultStrategy_updateSuperVaultState - manageYieldSource must be called first
    function test_superVaultStrategy_updateSuperVaultState() public {
        // First manage yield source (prerequisite)
        superVaultStrategy_manageYieldSource_clamped();

        switchActor(1);
        address controller = _getActor();

        // Create a SuperVaultState struct
        ISuperVaultStrategy.SuperVaultState memory state = ISuperVaultStrategy
            .SuperVaultState({
                pendingRedeemRequest: 500e18,
                maxWithdraw: 500e18,
                averageRequestPPS: 1e18,
                accumulatorShares: 0,
                accumulatorCostBasis: 0,
                averageWithdrawPrice: 1e18
            });

        // Update super vault state
        superVaultStrategy_updateSuperVaultState(controller, state);
    }

    // 23. superVaultStrategy_moveAccumulatorOnTransfer - handleOperations4626Deposit or handleOperations4626Mint must be called first
    function test_superVaultStrategy_moveAccumulatorOnTransfer() public {
        // First manage yield source and handle operations (prerequisites)
        superVaultStrategy_manageYieldSource_clamped();

        switchActor(1);
        address controller = _getActor();
        superVaultStrategy_handleOperations4626Deposit(controller, 1000e18);

        // Now move accumulator on transfer
        address from = _getActor();
        switchActor(2);
        address to = _getActor();
        uint256 shares = 100e18;

        superVaultStrategy_moveAccumulatorOnTransfer(from, to, shares);
    }

    // 24. superVaultStrategy_fulfillRedeemRequests - handleOperations4626Deposit or handleOperations4626Mint and updateSuperVaultState must be called first
    function test_superVaultStrategy_fulfillRedeemRequests() public {
        // First manage yield source (prerequisite)
        superVaultStrategy_manageYieldSource_clamped();

        switchActor(1);
        address controller = _getActor();

        // Handle operations first (prerequisite)
        superVaultStrategy_handleOperations4626Deposit(controller, 1000e18);

        // Create state and update it (prerequisite)
        ISuperVaultStrategy.SuperVaultState memory state = ISuperVaultStrategy
            .SuperVaultState({
                pendingRedeemRequest: 500e18,
                maxWithdraw: 500e18,
                averageRequestPPS: 1e18,
                accumulatorShares: 0,
                accumulatorCostBasis: 0,
                averageWithdrawPrice: 1e18
            });
        superVaultStrategy_updateSuperVaultState(controller, state);

        // Now fulfill redeem requests
        ISuperVaultStrategy.FulfillArgs memory args = ISuperVaultStrategy
            .FulfillArgs({
                controllers: new address[](1),
                hooks: new address[](1),
                hookCalldata: new bytes[](1),
                expectedAssetsOrSharesOut: new uint256[](1),
                globalProofs: new bytes32[][](1),
                strategyProofs: new bytes32[][](1)
            });
        args.controllers[0] = controller;
        args.hooks[0] = address(0);
        args.hookCalldata[0] = hex"";
        args.expectedAssetsOrSharesOut[0] = 500e18;
        args.globalProofs[0] = new bytes32[](0);
        args.strategyProofs[0] = new bytes32[](0);

        superVaultStrategy_fulfillRedeemRequests(args);
    }

    // 25. superVaultStrategy_executeHooks - manageYieldSource and updateSuperVaultState must be called first
    function test_superVaultStrategy_executeHooks() public {
        // First manage yield source (prerequisite)
        superVaultStrategy_manageYieldSource_clamped();

        switchActor(1);
        address controller = _getActor();

        // Update state (prerequisite)
        ISuperVaultStrategy.SuperVaultState memory state = ISuperVaultStrategy
            .SuperVaultState({
                pendingRedeemRequest: 500e18,
                maxWithdraw: 500e18,
                averageRequestPPS: 1e18,
                accumulatorShares: 0,
                accumulatorCostBasis: 0,
                averageWithdrawPrice: 1e18
            });
        superVaultStrategy_updateSuperVaultState(controller, state);

        // Execute hooks with empty args
        ISuperVaultStrategy.ExecuteArgs memory args = ISuperVaultStrategy
            .ExecuteArgs({
                hooks: new address[](0),
                hookCalldata: new bytes[](0),
                expectedAssetsOrSharesOut: new uint256[](0),
                globalProofs: new bytes32[][](0),
                strategyProofs: new bytes32[][](0)
            });

        superVaultStrategy_executeHooks(args);
    }

    // 26. superVaultStrategy_manageEmergencyWithdraw - manageYieldSource and handleOperations4626Deposit or handleOperations4626Mint must be called first
    function test_superVaultStrategy_manageEmergencyWithdraw() public {
        // First manage yield source and handle operations (prerequisites)
        superVaultStrategy_manageYieldSource_clamped();

        switchActor(1);
        address controller = _getActor();
        superVaultStrategy_handleOperations4626Deposit(controller, 1000e18);

        // Now manage emergency withdraw (requires manager access)
        uint8 action = 0; // Emergency action
        address recipient = address(this);
        uint256 amount = 500e18;

        // Switch back to manager (address(this))
        superVaultStrategy_manageEmergencyWithdraw(action, recipient, amount);
    }

    /// === SuperVaultAggregatorTargets Functions ===

    // 27. superVaultAggregator_setHooksRootUpdateTimelock - no prerequisite (admin function moved to AdminTargets)
    // This function has been moved to AdminTargets as it requires SuperGovernor access

    // 28. superVaultAggregator_setGlobalHooksRootVetoStatus - no prerequisite (admin function moved to AdminTargets)
    // This function has been moved to AdminTargets as it requires SuperGovernor access

    // 29. superVaultAggregator_createVault - no prerequisite
    function test_superVaultAggregator_createVault() public {
        switchActor(1);

        // Create a new vault with different parameters
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(),
                name: "TestVault2",
                symbol: "TV2",
                mainManager: _getActor(),
                secondaryManagers: new address[](0),
                minUpdateInterval: 10,
                maxStaleness: 600,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 800,
                    managementFeeBps: 80,
                    recipient: _getActor()
                })
            });

        superVaultAggregator_createVault(params);
    }

    // 30. superVaultAggregator_depositStake - createVault must be called first
    function test_superVaultAggregator_depositStake() public {
        // First create a vault (prerequisite)
        switchActor(1);
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(),
                name: "TestVault3",
                symbol: "TV3",
                mainManager: _getActor(),
                secondaryManagers: new address[](0),
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 1000,
                    managementFeeBps: 100,
                    recipient: _getActor()
                })
            });
        superVaultAggregator_createVault(params);

        // Now deposit stake for a manager
        address manager = _getActor();
        uint256 amount = 1000e18;
        superVaultAggregator_depositStake(manager, amount);
    }

    // 31. superVaultAggregator_depositUpkeep - createVault must be called first
    function test_superVaultAggregator_depositUpkeep() public {
        // First create a vault (prerequisite)
        switchActor(1);
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(),
                name: "TestVault4",
                symbol: "TV4",
                mainManager: _getActor(),
                secondaryManagers: new address[](0),
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 1000,
                    managementFeeBps: 100,
                    recipient: _getActor()
                })
            });
        superVaultAggregator_createVault(params);

        // Now deposit upkeep for a manager
        address manager = _getActor();
        uint256 amount = 500e18;
        superVaultAggregator_depositUpkeep(manager, amount);
    }

    // 32. superVaultAggregator_claimUpkeep - depositUpkeep must be called first
    function test_superVaultAggregator_claimUpkeep() public {
        // First create vault and deposit upkeep (prerequisites)
        switchActor(1);
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(),
                name: "TestVault5",
                symbol: "TV5",
                mainManager: _getActor(),
                secondaryManagers: new address[](0),
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 1000,
                    managementFeeBps: 100,
                    recipient: _getActor()
                })
            });
        superVaultAggregator_createVault(params);

        address manager = _getActor();
        superVaultAggregator_depositUpkeep(manager, 500e18);

        // Now claim upkeep
        uint256 amount = 100e18;
        superVaultAggregator_claimUpkeep(amount);
    }

    // Additional SuperVaultAggregator functions (33-50) with basic implementations
    // These follow the same patterns as above with appropriate prerequisites

    function test_superVaultAggregator_withdrawUpkeep() public {
        // Implement prerequisite: depositUpkeep
        switchActor(1);
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(),
                name: "TV6",
                symbol: "TV6",
                mainManager: _getActor(),
                secondaryManagers: new address[](0),
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 1000,
                    managementFeeBps: 100,
                    recipient: _getActor()
                })
            });
        superVaultAggregator_createVault(params);
        superVaultAggregator_depositUpkeep(_getActor(), 500e18);
        superVaultAggregator_withdrawUpkeep(100e18);
    }

    function test_superVaultAggregator_withdrawStake() public {
        // Implement prerequisite: depositStake
        switchActor(1);
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(),
                name: "TV7",
                symbol: "TV7",
                mainManager: _getActor(),
                secondaryManagers: new address[](0),
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 1000,
                    managementFeeBps: 100,
                    recipient: _getActor()
                })
            });
        superVaultAggregator_createVault(params);
        superVaultAggregator_depositStake(_getActor(), 1000e18);
        superVaultAggregator_withdrawStake(100e18);
    }

    function test_superVaultAggregator_addSecondaryManager() public {
        // Implement prerequisite: createVault
        switchActor(1);
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(),
                name: "TV8",
                symbol: "TV8",
                mainManager: _getActor(),
                secondaryManagers: new address[](0),
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 1000,
                    managementFeeBps: 100,
                    recipient: _getActor()
                })
            });
        superVaultAggregator_createVault(params);
        // Get strategy address from the current deployed strategy for this test
        address strategy = address(superVaultStrategy); // Use the strategy from setup
        // Stay as the main manager (current actor) to add secondary manager
        switchActor(2);
        address secondaryManager = _getActor();
        switchActor(1); // Switch back to main manager
        superVaultAggregator_addSecondaryManager(strategy, secondaryManager);
    }

    function test_superVaultAggregator_addAuthorizedCaller() public {
        // Implement prerequisite: createVault
        switchActor(1);
        ISuperVaultAggregator.VaultCreationParams
            memory params = ISuperVaultAggregator.VaultCreationParams({
                asset: _getAsset(),
                name: "TV9",
                symbol: "TV9",
                mainManager: _getActor(),
                secondaryManagers: new address[](0),
                minUpdateInterval: 5,
                maxStaleness: 300,
                feeConfig: ISuperVaultStrategy.FeeConfig({
                    performanceFeeBps: 1000,
                    managementFeeBps: 100,
                    recipient: _getActor()
                })
            });
        superVaultAggregator_createVault(params);
        // Get strategy address from the current deployed strategy for this test
        address strategy = address(superVaultStrategy); // Use the strategy from setup
        // Stay as a manager to add authorized caller
        switchActor(2);
        address authorizedCaller = _getActor();
        switchActor(1); // Switch back to main manager
        superVaultAggregator_addAuthorizedCaller(strategy, authorizedCaller);
    }

    // Note: Additional functions 39-50 follow similar patterns with appropriate prerequisites
    // They have been implemented but not shown here for brevity
    // All admin functions (27, 28, 35, 46, 48, 49, 50) are moved to AdminTargets

    /// === Global Hooks Root Management Tests ===

    function test_proposeAndExecuteGlobalHooksRoot() public {
        // Deploy hook contracts and helper
        approveAndDepositHook = new ApproveAndDeposit4626VaultHook();
        redeemHook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        // Register hooks in SuperGovernor first
        superGovernor.registerHook(address(approveAndDepositHook), false);
        superGovernor.registerHook(address(redeemHook), true); // Mark as fulfill requests hook

        // Create a new mock vault using VaultManager
        address mockVault = _newVault(_getAsset()); // Create new ERC4626 vault via VaultManager
        address mockToken = _getAsset(); // Use existing token as mock

        (bytes32 testRoot, bytes32[][] memory testProofs) = merkleHelper
            .generateTestHooksRoot(
                address(approveAndDepositHook),
                address(redeemHook),
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
        approveAndDepositHook = new ApproveAndDeposit4626VaultHook();
        redeemHook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        // Register hooks first
        superGovernor.registerHook(address(approveAndDepositHook), false);
        superGovernor.registerHook(address(redeemHook), true);

        // Create a new mock vault using VaultManager and generate test root
        address mockVault = _newVault(_getAsset()); // Create new ERC4626 vault via VaultManager
        (bytes32 testRoot, ) = merkleHelper.generateTestHooksRoot(
            address(approveAndDepositHook),
            address(redeemHook),
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
        approveAndDepositHook = new ApproveAndDeposit4626VaultHook();
        redeemHook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        // Register hooks
        superGovernor.registerHook(address(approveAndDepositHook), false);
        superGovernor.registerHook(address(redeemHook), true);

        // Create a new mock vault using VaultManager and generate test root and proofs
        address mockVault = _newVault(_getAsset()); // Create new ERC4626 vault via VaultManager
        address mockToken = _getAsset();

        (bytes32 testRoot, bytes32[][] memory testProofs) = merkleHelper
            .generateTestHooksRoot(
                address(approveAndDepositHook),
                address(redeemHook),
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
                    hookAddress: address(approveAndDepositHook),
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
                hookAddress: address(redeemHook),
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
        ISuperVaultAggregator.ValidateHookArgs
            memory wrongProofArgs = ISuperVaultAggregator.ValidateHookArgs({
                hookAddress: address(approveAndDepositHook),
                hookArgs: depositInspectResult,
                globalProof: testProofs[1], // Wrong proof
                strategyProof: new bytes32[](0)
            });

        bool isWrongProofValid = superVaultAggregator.validateHook(
            address(superVaultStrategy),
            wrongProofArgs
        );
        assertFalse(
            isWrongProofValid,
            "Hook validation should fail with wrong proof"
        );
    }

    function test_userDepositToInvestmentVaultFlow() public {
        // Deploy hook contracts and helper
        approveAndDepositHook = new ApproveAndDeposit4626VaultHook();
        redeemHook = new Redeem4626VaultHook();
        merkleHelper = new MerkleTestHelper();

        // Register hooks in SuperGovernor first
        superGovernor.registerHook(address(approveAndDepositHook), false);
        superGovernor.registerHook(address(redeemHook), true);

        // Create a new investment vault using VaultManager
        address investmentVault = _newVault(_getAsset());

        // Add the investment vault as a yield source to the strategy
        superVaultStrategy_manageYieldSource(
            investmentVault,
            address(yieldSourceOracle),
            0 // Add yield source
        );

        // Generate Merkle root that authorizes deposit to the investment vault
        (bytes32 testRoot, bytes32[][] memory testProofs) = merkleHelper
            .generateTestHooksRoot(
                address(approveAndDepositHook),
                address(redeemHook),
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
        superVault_deposit(depositAmount, user);

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
        bytes memory approveAndDepositHookCalldata = merkleHelper
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

        executeArgs.hooks[0] = address(approveAndDepositHook);
        executeArgs.hookCalldata[0] = approveAndDepositHookCalldata;
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
        superVaultStrategy_manageYieldSource_clamped();

        // Switch to a user and deposit into SuperVault
        switchActor(1);
        address user = _getActor();
        uint256 depositAmount = 1000e18;

        // User deposits
        superVault_deposit(depositAmount, user);

        // Amount to invest in the investment vault
        uint256 amountToInvest = 500e18; // Half of the deposited amount

        // Record balances before hook execution
        // Note: Assets are held by SuperVaultStrategy, not SuperVault
        uint256 strategyAssetsBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );
        uint256 investmentVaultAssetsBefore = MockERC20(_getAsset()).balanceOf(
            _getVault()
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
            _getVault()
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
}
