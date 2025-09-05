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
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function superVaultStrategy_executeHooks_clamped(
        bool depositHook,
        uint256 amountToInvest
    ) public payable {
        // Clamp to the strategy's asset balance (not SuperVault's balance)
        amountToInvest %= MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );

        // Create hook calldata for ApproveAndDeposit4626VaultHook
        bytes memory approveAndDepositCalldata = abi.encodePacked(
            bytes32(0), // yieldSourceOracleId placeholder
            _getYieldSource(), // Address of the yield source
            _getAsset(), // Address of the token to approve and deposit
            amountToInvest, // Amount to deposit
            false
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

        executeArgs.hooks[0] = depositHook
            ? address(approveAndDeposit4626Hook)
            : address(redeem4626Hook);
        executeArgs.hookCalldata[0] = approveAndDepositCalldata;
        executeArgs.expectedAssetsOrSharesOut[0] = amountToInvest;
        executeArgs.globalProofs[0] = new bytes32[](1);
        executeArgs.strategyProofs[0] = new bytes32[](1);

        // Execute the hook to transfer funds to investment vault (with automatic approval)
        this.superVaultStrategy_executeHooks{value: msg.value}(executeArgs);
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

    function superVaultAggregator_slashStake(
        address manager,
        uint256 amount
    ) public asAdmin {
        superVaultAggregator.slashStake(manager, amount);
    }
}
