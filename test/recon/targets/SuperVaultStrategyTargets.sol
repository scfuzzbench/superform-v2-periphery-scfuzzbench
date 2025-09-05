// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import {YieldSourceType} from "test/recon/managers/YieldManager.sol";
import "src/SuperVault/SuperVaultStrategy.sol";

abstract contract SuperVaultStrategyTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    /// @dev Clamps the action type to 0 to add a vault as a yield source
    function superVaultStrategy_manageYieldSource_clamped(
        YieldSourceType sourceType
    ) public {
        address yieldSourceOracle = _getYieldSourceOracleForType(sourceType);

        superVaultStrategy_manageYieldSource(
            _getYieldSource(),
            yieldSourceOracle,
            0
        );
    }

    function superVaultStrategy_handleOperations7540_clamped(
        uint256 operation,
        uint256 amount
    ) public {
        operation %= 6; // clamp by the possible operation types in the enum
        superVaultStrategy_handleOperations7540(
            ISuperVaultStrategy.Operation(operation),
            _getActor(),
            _getActor(),
            amount
        );
    }

    function superVaultStrategy_fulfillRedeemRequests_clamped(
        uint256 redeemAmount
    ) public {
        // Clamp the redeem amount to a reasonable range (1 to 1000 ether)
        redeemAmount = (redeemAmount % 1000e18) + 1e18;
        
        // Create a realistic controller address
        address[] memory controllers = new address[](1);
        controllers[0] = _getActor();
        
        // Select redeem hook based on current yield source type
        address redeemHook = _getRedeemHookForType(_getCurrentYieldSourceType());
        
        // Create realistic hook calldata for redeem operation
        // Layout: bytes32 oracleId, address yieldSource, address owner, uint256 shares, bool usePrevAmount
        bytes memory redeemHookCalldata = abi.encodePacked(
            bytes32(0), // yieldSourceOracleId placeholder (ignored with UnsafeSuperVaultAggregator)
            _getYieldSource(), // Current active yield source
            address(superVaultStrategy), // Owner (strategy owns the yield source shares)
            redeemAmount, // Amount to redeem
            false // Don't use previous hook amount
        );
        
        // Create arrays for FulfillArgs
        address[] memory hooks = new address[](1);
        hooks[0] = redeemHook;
        
        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = redeemHookCalldata;
        
        uint256[] memory expectedAssetsOrSharesOut = new uint256[](1);
        expectedAssetsOrSharesOut[0] = redeemAmount; // Expect 1:1 redemption for simplicity
        
        bytes32[][] memory globalProofs = new bytes32[][](1);
        globalProofs[0] = new bytes32[](0); // Empty proof for UnsafeSuperVaultAggregator
        
        bytes32[][] memory strategyProofs = new bytes32[][](1);
        strategyProofs[0] = new bytes32[](0); // Empty proof
        
        // Create the FulfillArgs struct
        ISuperVaultStrategy.FulfillArgs memory fulfillArgs = ISuperVaultStrategy.FulfillArgs({
            controllers: controllers,
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedAssetsOrSharesOut,
            globalProofs: globalProofs,
            strategyProofs: strategyProofs
        });
        
        // Execute the function
        superVaultStrategy_fulfillRedeemRequests(fulfillArgs);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

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
