// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

// Targets
// NOTE: Always import and apply them in alphabetical order, so much easier to debug!
import { AdminTargets } from "./targets/AdminTargets.sol";
import { DoomsdayTargets } from "./targets/DoomsdayTargets.sol";
import { ManagersTargets } from "./targets/ManagersTargets.sol";
import { SuperVaultTargets } from "./targets/SuperVaultTargets.sol";
import { SuperVaultAggregatorTargets } from "./targets/SuperVaultAggregatorTargets.sol";
import { SuperVaultEscrowTargets } from "./targets/SuperVaultEscrowTargets.sol";
import { SuperVaultStrategyTargets } from "./targets/SuperVaultStrategyTargets.sol";

abstract contract TargetFunctions is
    AdminTargets,
    DoomsdayTargets,
    ManagersTargets,
    SuperVaultTargets,
    SuperVaultAggregatorTargets,
    SuperVaultEscrowTargets,
    SuperVaultStrategyTargets
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///


    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}
