// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";

import {vm} from "@chimera/Hevm.sol";
import {Panic} from "@recon/Panic.sol";
import {MockERC20} from "@recon/MockERC20.sol";

import "src/SuperVault/SuperVaultStrategy.sol";

import {YieldSourceType} from "test/recon/managers/YieldManager.sol";
import {BeforeAfter, OpType} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";

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
        // Clamp the redeem amount to a reasonable range (1 to 100 ether)
        if (redeemAmount == 0) redeemAmount = 1e18;
        if (redeemAmount > 100e18) redeemAmount = 100e18;

        // Create a realistic controller address
        address[] memory controllers = new address[](1);
        controllers[0] = _getActor();

        // Determine yield source type from currently active yield source
        YieldSourceType activeYieldSourceType = _getYieldSourceTypeFromAddress(
            _getYieldSource()
        );
        address redeemHook = _getRedeemHookForType(activeYieldSourceType);

        // Create realistic hook calldata for redeem operation
        bytes memory redeemHookCalldata;

        if (
            activeYieldSourceType == YieldSourceType.ERC4626 ||
            activeYieldSourceType == YieldSourceType.ERC5115
        ) {
            // ERC4626/ERC5115 Layout: bytes32 oracleId, address yieldSource, address owner, uint256 shares, bool usePrevAmount
            redeemHookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Current active yield source
                address(superVaultStrategy), // Owner (strategy owns the yield source shares)
                redeemAmount, // Amount to redeem
                false // Don't use previous hook amount
            );
        } else {
            // ERC7540 Layout: bytes32 oracleId, address yieldSource, uint256 shares, bool usePrevAmount
            redeemHookCalldata = abi.encodePacked(
                bytes32(0), // yieldSourceOracleId placeholder
                _getYieldSource(), // Current active yield source
                redeemAmount, // Amount to redeem
                false // Don't use previous hook amount
            );
        }

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
        ISuperVaultStrategy.FulfillArgs memory fulfillArgs = ISuperVaultStrategy
            .FulfillArgs({
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

    /// @dev Property: redemptions only burn the requested amount of shares (exact check)
    /// @dev Property: accumulatorShares decreases by the exact amounts requested when fulfilling redemptions
    /// @dev Property: accumulatorCostBasis decrease by the exact amounts requested when fulfilling redemptions
    function superVaultStrategy_fulfillRedeemRequests(
        ISuperVaultStrategy.FulfillArgs memory args
    ) public updateGhostsWithOpType(OpType.FULFILL) {
        address[] memory controllers = args.controllers;
        uint256 pendingRedeemBefore = _requestedSharesForControllers(
            controllers
        );
        (
            uint256 sumAccumulatorSharesBefore,
            uint256 sumAccumulatorCostBasisBefore
        ) = _sumSuperVaultValsForControllers(controllers);
        uint256 totalSharesBefore = superVault.totalSupply();
        uint256 assetBalanceBefore = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );

        vm.prank(_getActor());
        superVaultStrategy.fulfillRedeemRequests(args);

        uint256 pendingRedeemAfter = _requestedSharesForControllers(
            controllers
        );
        (
            uint256 sumAccumulatorSharesAfter,
            uint256 sumAccumulatorCostBasisAfter
        ) = _sumSuperVaultValsForControllers(controllers);
        uint256 totalSharesAfter = superVault.totalSupply();
        uint256 assetBalanceAfter = MockERC20(_getAsset()).balanceOf(
            address(superVaultStrategy)
        );

        eq(
            pendingRedeemBefore - pendingRedeemAfter,
            totalSharesBefore - totalSharesAfter,
            "redemptions only burn the requested amount of shares"
        );
        eq(
            sumAccumulatorSharesBefore - sumAccumulatorSharesAfter,
            totalSharesBefore - totalSharesAfter,
            "accumulatorShares decreases by the exact amounts requested when fulfilling redemptions"
        );
        // asset balance should increase
        eq(
            assetBalanceAfter - assetBalanceBefore,
            sumAccumulatorCostBasisBefore - sumAccumulatorCostBasisAfter,
            "accumulatorShares decreases by the exact amounts requested when fulfilling redemptions"
        );
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

    /// Helpers

    function _requestedSharesForControllers(
        address[] memory controllers
    ) internal returns (uint256) {
        uint256 totalRequested;
        for (uint256 i; i < controllers.length; i++) {
            totalRequested += superVault.pendingRedeemRequest(
                0,
                controllers[i]
            );
        }

        return totalRequested;
    }

    // Helpers
    function _sumSuperVaultValsForControllers(
        address[] memory controllers
    )
        internal
        view
        returns (uint256 sumAccumulatorShares, uint256 sumAccumulatorCostBasis)
    {
        for (uint256 i; i < controllers.length; i++) {
            sumAccumulatorShares += superVaultStrategy
                .getSuperVaultState(controllers[i])
                .accumulatorShares;
            sumAccumulatorCostBasis += superVaultStrategy
                .getSuperVaultState(controllers[i])
                .accumulatorCostBasis;
        }
    }
}
