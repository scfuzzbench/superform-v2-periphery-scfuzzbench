// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// External dependencies
import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";
import {MockERC20} from "@recon/MockERC20.sol";

// System dependencies
import {ISuperVaultStrategy} from "src/interfaces/SuperVault/ISuperVaultStrategy.sol";

// Test dependencies
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";

abstract contract AdminTargets is BaseTargetFunctions, Properties {
    enum HookType {
        // ERC4626 Hooks
        ApproveAndDeposit4626,
        Deposit4626,
        Redeem4626,
        // ERC5115 Hooks
        ApproveAndDeposit5115,
        Deposit5115,
        Redeem5115,
        // ERC7540 Hooks
        Deposit7540,
        Redeem7540,
        RequestDeposit7540,
        RequestRedeem7540,
        ApproveAndRequestDeposit7540,
        ApproveAndRequestRedeem7540,
        CancelDepositRequest7540,
        CancelRedeemRequest7540,
        ClaimCancelDepositRequest7540,
        ClaimCancelRedeemRequest7540,
        Withdraw7540
    }

    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function superVaultStrategy_executeHooks_clamped(
        uint256 hookTypeInt,
        uint256 amountToInvest,
        bool usePrevHookAmount
    ) public payable {
        // Convert integer to enum (will wrap around if > max enum value)
        HookType hookType = HookType(hookTypeInt % 17); // 17 is the total number of hooks

        // Clamp to the strategy's asset balance (not SuperVault's balance)
        amountToInvest %= MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );

        // Get the hook address and calldata
        (address hookAddress, bytes memory hookCalldata) = _getHookAddressAndCalldata(
            hookType,
            amountToInvest,
            usePrevHookAmount
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

        executeArgs.hooks[0] = hookAddress;
        executeArgs.hookCalldata[0] = hookCalldata;
        executeArgs.expectedAssetsOrSharesOut[0] = amountToInvest;
        executeArgs.globalProofs[0] = new bytes32[](1);
        executeArgs.strategyProofs[0] = new bytes32[](1);

        // Execute the hook
        this.superVaultStrategy_executeHooks{value: msg.value}(executeArgs);
    }

    function _getHookAddressAndCalldata(
        HookType hookType,
        uint256 amountToInvest,
        bool usePrevHookAmount
    ) internal view returns (address hookAddress, bytes memory hookCalldata) {
        if (hookType == HookType.ApproveAndDeposit4626) {
            hookAddress = address(approveAndDeposit4626Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                _getAsset(), // Address of the token to approve and deposit
                amountToInvest, // Amount to deposit
                usePrevHookAmount
            );
        } else if (hookType == HookType.Deposit4626) {
            hookAddress = address(deposit4626Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                amountToInvest, // Amount to deposit
                usePrevHookAmount
            );
        } else if (hookType == HookType.Redeem4626) {
            hookAddress = address(redeem4626Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                amountToInvest, // Amount to redeem
                address(superVaultStrategy), // Receiver
                address(superVaultStrategy) // Owner
            );
        } else if (hookType == HookType.ApproveAndDeposit5115) {
            hookAddress = address(approveAndDeposit5115Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                _getAsset(), // Address of the token to approve and deposit
                bytes32(0), // tokenId (for ERC5115)
                amountToInvest, // Amount to deposit
                usePrevHookAmount
            );
        } else if (hookType == HookType.Deposit5115) {
            hookAddress = address(deposit5115Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                bytes32(0), // tokenId (for ERC5115)
                amountToInvest, // Amount to deposit
                usePrevHookAmount
            );
        } else if (hookType == HookType.Redeem5115) {
            hookAddress = address(redeem5115Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                bytes32(0), // tokenId (for ERC5115)
                amountToInvest, // Amount to redeem
                address(superVaultStrategy), // Receiver
                address(superVaultStrategy) // Owner
            );
        } else if (hookType == HookType.Deposit7540) {
            hookAddress = address(deposit7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                amountToInvest, // Amount to deposit
                address(superVaultStrategy), // Receiver
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.Redeem7540) {
            hookAddress = address(redeem7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                amountToInvest, // Amount to redeem
                address(superVaultStrategy), // Receiver
                address(superVaultStrategy), // Owner
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.RequestDeposit7540) {
            hookAddress = address(requestDeposit7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                amountToInvest, // Amount to request deposit
                address(superVaultStrategy), // Owner
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.RequestRedeem7540) {
            hookAddress = address(requestRedeem7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                amountToInvest, // Amount to request redeem
                address(superVaultStrategy), // Owner
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.ApproveAndRequestDeposit7540) {
            hookAddress = address(approveAndRequestDeposit7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                _getAsset(), // Address of the token to approve
                amountToInvest, // Amount to request deposit
                address(superVaultStrategy), // Owner
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.ApproveAndRequestRedeem7540) {
            hookAddress = address(approveAndRequestRedeem7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                amountToInvest, // Amount to request redeem
                address(superVaultStrategy), // Owner
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.CancelDepositRequest7540) {
            hookAddress = address(cancelDepositRequest7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.CancelRedeemRequest7540) {
            hookAddress = address(cancelRedeemRequest7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.ClaimCancelDepositRequest7540) {
            hookAddress = address(claimCancelDepositRequest7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                address(superVaultStrategy), // Receiver
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.ClaimCancelRedeemRequest7540) {
            hookAddress = address(claimCancelRedeemRequest7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                address(superVaultStrategy), // Receiver
                address(superVaultStrategy) // Controller
            );
        } else if (hookType == HookType.Withdraw7540) {
            hookAddress = address(withdraw7540Hook);
            hookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Address of the yield source
                amountToInvest, // Amount to withdraw
                address(superVaultStrategy), // Receiver
                address(superVaultStrategy), // Owner
                address(superVaultStrategy) // Controller
            );
        }
    }

    // Keep the original function for backwards compatibility
    function superVaultStrategy_executeHooks_clamped(
        bool depositHook,
        uint256 amountToInvest
    ) public payable {
        // Call the generalized version with appropriate hook type
        // depositHook=true maps to ApproveAndDeposit4626 (enum value 0)
        // depositHook=false maps to Redeem4626 (enum value 2)
        uint256 hookType = depositHook ? 0 : 2;
        superVaultStrategy_executeHooks_clamped(hookType, amountToInvest, false);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function superVaultStrategy_executeHooks(
        ISuperVaultStrategy.ExecuteArgs memory args
    ) public payable asAdmin {
        superVaultStrategy.executeHooks{value: msg.value}(args);
    }

    // Functions that require SuperGovernor access
    /// @dev removed because we're bypassing hook validation
    // function superVaultAggregator_setHooksRootUpdateTimelock(
    //     uint256 newTimelock
    // ) public asAdmin {
    //     superVaultAggregator.setHooksRootUpdateTimelock(newTimelock);
    // }

    /// @dev removed because we're bypassing hook validation
    // function superVaultAggregator_proposeGlobalHooksRoot(
    //     bytes32 newRoot
    // ) public asAdmin {
    //     superVaultAggregator.proposeGlobalHooksRoot(newRoot);
    // }

    /// @dev removed because we're bypassing hook validation
    // function superVaultAggregator_executeGlobalHooksRootUpdate()
    //     public
    //     asAdmin
    // {
    //     superVaultAggregator.executeGlobalHooksRootUpdate();
    // }

    /// @dev removed because we're bypassing hook validation
    // function superVaultAggregator_setGlobalHooksRootVetoStatus(
    //     bool vetoed
    // ) public asAdmin {
    //     superVaultAggregator.setGlobalHooksRootVetoStatus(vetoed);
    // }

    /// @dev removed because we're bypassing hook validation
    // function superVaultAggregator_setStrategyHooksRootVetoStatus(
    //     address strategy,
    //     bool vetoed
    // ) public asAdmin {
    //     superVaultAggregator.setStrategyHooksRootVetoStatus(strategy, vetoed);
    // }

    function superVaultAggregator_changePrimaryManager(
        address strategy,
        address newManager
    ) public asAdmin {
        superVaultAggregator.changePrimaryManager(strategy, newManager);
    }

    /// @dev won't achieve coverage until issue outlined here is resolved: https://github.com/Recon-Fuzz/superform-review/issues/5
    function superVaultAggregator_slashStake(
        address manager,
        uint256 amount
    ) public asAdmin {
        superVaultAggregator.slashStake(manager, amount);
    }
}
