// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "src/SuperGovernor.sol";

abstract contract SuperGovernorTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///
    function superGovernor_proposeGlobalHooksRoot_clamped(
        bytes32 newRoot
    ) public {
        (bytes32 testRoot, bytes32[][] memory testProofs) = merkleHelper
            .generateTestHooksRoot(
                address(approveAndDepositHook),
                address(redeemHook),
                _getVault(),
                _getAsset()
            );

        superGovernor_proposeGlobalHooksRoot(testRoot);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function superGovernor_proposeGlobalHooksRoot(
        bytes32 newRoot
    ) public asActor {
        superGovernor.proposeGlobalHooksRoot(newRoot);
    }
}
