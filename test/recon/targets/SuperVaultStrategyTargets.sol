// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "src/SuperVault/SuperVaultStrategy.sol";

abstract contract SuperVaultStrategyTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    /// @dev Clamps the action type to 0 to add a vault as a yield source
    function superVaultStrategy_manageYieldSource_clamped() public {
        superVaultStrategy_manageYieldSource(
            _getVault(),
            address(yieldSourceOracle),
            0
        );
    }

    function superVaultStrategy_executeHooks_clamped(
        bool depositHook,
        uint256 amountToInvest
    ) public payable {
        (, bytes32[][] memory testProofs) = merkleHelper.generateTestHooksRoot(
            address(approveAndDepositHook), // Use ApproveAndDeposit hook instead of basic Deposit hook
            address(redeemHook),
            _getVault(),
            _getAsset()
        );

        // Create hook calldata for ApproveAndDeposit4626VaultHook
        bytes memory approveAndDepositCalldata = abi.encodePacked(
            bytes32(0), // yieldSourceOracleId placeholder
            _getVault(), // Address of the yield source vault
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
            ? address(approveAndDepositHook)
            : address(redeemHook);
        executeArgs.hookCalldata[0] = approveAndDepositCalldata;
        executeArgs.expectedAssetsOrSharesOut[0] = amountToInvest;
        executeArgs.globalProofs[0] = depositHook
            ? testProofs[0]
            : testProofs[1];
        executeArgs.strategyProofs[0] = new bytes32[](0);

        // Execute the hook to transfer funds to investment vault (with automatic approval)
        this.superVaultStrategy_executeHooks{value: msg.value}(executeArgs);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function superVaultStrategy_executeHooks(
        ISuperVaultStrategy.ExecuteArgs memory args
    ) public payable asActor {
        superVaultStrategy.executeHooks{value: msg.value}(args);
    }

    function superVaultStrategy_executeVaultFeeConfigUpdate() public asActor {
        superVaultStrategy.executeVaultFeeConfigUpdate();
    }

    function superVaultStrategy_fulfillRedeemRequests(
        ISuperVaultStrategy.FulfillArgs memory args
    ) public asActor {
        superVaultStrategy.fulfillRedeemRequests(args);
    }

    function superVaultStrategy_handleOperations4626Deposit(
        address controller,
        uint256 assetsGross
    ) public asActor {
        superVaultStrategy.handleOperations4626Deposit(controller, assetsGross);
    }

    function superVaultStrategy_handleOperations4626Mint(
        address controller,
        uint256 sharesNet,
        uint256 assetsGross,
        uint256 assetsNet
    ) public asActor {
        superVaultStrategy.handleOperations4626Mint(
            controller,
            sharesNet,
            assetsGross,
            assetsNet
        );
    }

    function superVaultStrategy_handleOperations7540(
        ISuperVaultStrategy.Operation operation,
        address controller,
        address receiver,
        uint256 amount
    ) public asActor {
        superVaultStrategy.handleOperations7540(
            operation,
            controller,
            receiver,
            amount
        );
    }

    function superVaultStrategy_manageEmergencyWithdraw(
        uint8 action,
        address recipient,
        uint256 amount
    ) public asActor {
        superVaultStrategy.manageEmergencyWithdraw(action, recipient, amount);
    }

    function superVaultStrategy_manageYieldSource(
        address source,
        address oracle,
        uint8 actionType
    ) public asActor {
        superVaultStrategy.manageYieldSource(source, oracle, actionType);
    }

    function superVaultStrategy_manageYieldSources(
        address[] memory sources,
        address[] memory oracles,
        uint8[] memory actionTypes
    ) public asActor {
        superVaultStrategy.manageYieldSources(sources, oracles, actionTypes);
    }

    function superVaultStrategy_moveAccumulatorOnTransfer(
        address from,
        address to,
        uint256 shares
    ) public asActor {
        superVaultStrategy.moveAccumulatorOnTransfer(from, to, shares);
    }

    function superVaultStrategy_proposeVaultFeeConfigUpdate(
        uint256 performanceFeeBps,
        uint256 managementFeeBps,
        address recipient
    ) public asActor {
        superVaultStrategy.proposeVaultFeeConfigUpdate(
            performanceFeeBps,
            managementFeeBps,
            recipient
        );
    }

    function superVaultStrategy_updateMaxPPSSlippage(
        uint256 maxSlippageBps
    ) public asActor {
        superVaultStrategy.updateMaxPPSSlippage(maxSlippageBps);
    }

    function superVaultStrategy_updateSuperVaultState(
        address controller,
        ISuperVaultStrategy.SuperVaultState memory state
    ) public asActor {
        superVaultStrategy.updateSuperVaultState(controller, state);
    }
}
