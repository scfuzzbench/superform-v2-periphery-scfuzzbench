// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";

// Helpers
import {Utils} from "@recon/Utils.sol";

// Your deps
import "src/SuperVault/SuperVault.sol";
import "src/SuperVault/SuperVaultAggregator.sol";
import "src/SuperVault/SuperVaultEscrow.sol";
import "src/SuperVault/SuperVaultStrategy.sol";

abstract contract Setup is BaseSetup, ActorManager, AssetManager, Utils {
    SuperVault superVault;
    SuperVaultAggregator superVaultAggregator;
    SuperVaultEscrow superVaultEscrow;
    SuperVaultStrategy superVaultStrategy;
    
    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        superVault = new SuperVault(); // TODO: Add parameters here
        superVaultAggregator = new SuperVaultAggregator(); // TODO: Add parameters here
        superVaultEscrow = new SuperVaultEscrow(); // TODO: Add parameters here
        superVaultStrategy = new SuperVaultStrategy(); // TODO: Add parameters here
    }

    /// === MODIFIERS === ///
    /// Prank admin and actor
    
    modifier asAdmin {
        vm.prank(address(this));
        _;
    }

    modifier asActor {
        vm.prank(address(_getActor()));
        _;
    }
}
