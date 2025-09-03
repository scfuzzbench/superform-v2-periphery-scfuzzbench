// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "src/SuperVault/SuperVaultAggregator.sol";

abstract contract SuperVaultAggregatorTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function superVaultAggregator_addAuthorizedCaller(address strategy, address caller) public asActor {
        superVaultAggregator.addAuthorizedCaller(strategy, caller);
    }

    function superVaultAggregator_addSecondaryManager(address strategy, address manager) public asActor {
        superVaultAggregator.addSecondaryManager(strategy, manager);
    }

    function superVaultAggregator_batchForwardPPS(ISuperVaultAggregator.BatchForwardPPSArgs memory args) public asActor {
        superVaultAggregator.batchForwardPPS(args);
    }

    function superVaultAggregator_changeGlobalLeavesStatus(bytes32[] memory leaves, bool[] memory statuses, address strategy) public asActor {
        superVaultAggregator.changeGlobalLeavesStatus(leaves, statuses, strategy);
    }

    function superVaultAggregator_claimUpkeep(uint256 amount) public asActor {
        superVaultAggregator.claimUpkeep(amount);
    }

    function superVaultAggregator_createVault(ISuperVaultAggregator.VaultCreationParams memory params) public asActor {
        superVaultAggregator.createVault(params);
    }

    function superVaultAggregator_depositStake(address manager, uint256 amount) public asActor {
        superVaultAggregator.depositStake(manager, amount);
    }

    function superVaultAggregator_depositUpkeep(address manager, uint256 amount) public asActor {
        superVaultAggregator.depositUpkeep(manager, amount);
    }

    function superVaultAggregator_executeChangePrimaryManager(address strategy) public asActor {
        superVaultAggregator.executeChangePrimaryManager(strategy);
    }

    function superVaultAggregator_executeStrategyHooksRootUpdate(address strategy) public asActor {
        superVaultAggregator.executeStrategyHooksRootUpdate(strategy);
    }

    function superVaultAggregator_forwardPPS(address updateAuthority, ISuperVaultAggregator.ForwardPPSArgs memory args) public asActor {
        superVaultAggregator.forwardPPS(updateAuthority, args);
    }

    function superVaultAggregator_proposeChangePrimaryManager(address strategy, address newManager) public asActor {
        superVaultAggregator.proposeChangePrimaryManager(strategy, newManager);
    }

    function superVaultAggregator_proposeStrategyHooksRoot(address strategy, bytes32 newRoot) public asActor {
        superVaultAggregator.proposeStrategyHooksRoot(strategy, newRoot);
    }

    function superVaultAggregator_removeAuthorizedCaller(address strategy, address caller) public asActor {
        superVaultAggregator.removeAuthorizedCaller(strategy, caller);
    }

    function superVaultAggregator_removeSecondaryManager(address strategy, address manager) public asActor {
        superVaultAggregator.removeSecondaryManager(strategy, manager);
    }

    function superVaultAggregator_updatePPSVerificationThresholds(address strategy, uint256 dispersionThreshold_, uint256 deviationThreshold_, uint256 mnThreshold_) public asActor {
        superVaultAggregator.updatePPSVerificationThresholds(strategy, dispersionThreshold_, deviationThreshold_, mnThreshold_);
    }

    function superVaultAggregator_withdrawStake(uint256 amount) public asActor {
        superVaultAggregator.withdrawStake(amount);
    }

    function superVaultAggregator_withdrawUpkeep(uint256 amount) public asActor {
        superVaultAggregator.withdrawUpkeep(amount);
    }
}