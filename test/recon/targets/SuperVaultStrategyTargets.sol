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

    function superVaultStrategy_initialize(
        address vaultAddress,
        ISuperVaultStrategy.FeeConfig memory feeConfigData
    ) public asActor {
        superVaultStrategy.initialize(vaultAddress, feeConfigData);
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
