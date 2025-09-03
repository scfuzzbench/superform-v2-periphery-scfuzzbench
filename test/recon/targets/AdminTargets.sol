// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

abstract contract AdminTargets is
    BaseTargetFunctions,
    Properties
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    // Functions that require SuperGovernor access
    function superVaultAggregator_setHooksRootUpdateTimelock(uint256 newTimelock) public asAdmin {
        superVaultAggregator.setHooksRootUpdateTimelock(newTimelock);
    }

    function superVaultAggregator_proposeGlobalHooksRoot(bytes32 newRoot) public asAdmin {
        superVaultAggregator.proposeGlobalHooksRoot(newRoot);
    }

    function superVaultAggregator_executeGlobalHooksRootUpdate() public asAdmin {
        superVaultAggregator.executeGlobalHooksRootUpdate();
    }

    function superVaultAggregator_setGlobalHooksRootVetoStatus(bool vetoed) public asAdmin {
        superVaultAggregator.setGlobalHooksRootVetoStatus(vetoed);
    }

    function superVaultAggregator_setStrategyHooksRootVetoStatus(address strategy, bool vetoed) public asAdmin {
        superVaultAggregator.setStrategyHooksRootVetoStatus(strategy, vetoed);
    }

    function superVaultAggregator_changePrimaryManager(address strategy, address newManager) public asAdmin {
        superVaultAggregator.changePrimaryManager(strategy, newManager);
    }

    function superVaultAggregator_slashStake(address manager, uint256 amount) public asAdmin {
        superVaultAggregator.slashStake(manager, amount);
    }
}