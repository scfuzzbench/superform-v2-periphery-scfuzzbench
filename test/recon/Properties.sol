// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Asserts} from "@chimera/Asserts.sol";

import {OpType} from "test/recon/BeforeAfter.sol";
import {BeforeAfter} from "./BeforeAfter.sol";

abstract contract Properties is BeforeAfter, Asserts {
    /// @dev Property: oracle PPS doesn't change on deposit/mint/redeem/withdraw
    function property_oraclePPSDoesntChangeOnAddOrRemove() public {
        if (_currentOp == OpType.ADD || _currentOp == OpType.REMOVE) {
            eq(
                _before.oraclePPS,
                _after.oraclePPS,
                "deposit/withdrawal changes oracle PPS"
            );
        }
    }

    /// @dev Property: naive PPS doesn't change on deposit/mint/redeem/withdraw
    function property_naivePPSDoesntChangeOnAddOrRemove() public {
        if (
            (_currentOp == OpType.ADD || _currentOp == OpType.REMOVE) &&
            _before.naivePPS != 0 // price starts as zero when no shares minted
        ) {
            eq(
                _before.naivePPS,
                _after.naivePPS,
                "deposit/withdrawal changes naive PPS"
            );
        }
    }

    /// @dev Property: fulfillRedeemRequest doesn't change naive PPS
    // NOTE: removed because it's expected behavior that fulfillment burns shares but doesn't transfer assets to users so would change the naively calculated price
    // function property_naivePPSDoesntChangeOnRedeem() public {
    //     if (_currentOp == OpType.FULFILL) {
    //         eq(
    //             _before.naivePPS,
    //             _after.naivePPS,
    //             "fulfilling redemption changes naive PPS"
    //         );
    //     }
    // }

    /// @dev Property: maxRedeem and maxWithdraw should always be equivalent
    function property_maxRedeemMaxWithdrawSymmetry() public {
        uint256 maxWithdraw = superVault.maxWithdraw(_getActor());
        uint256 maxWithdrawAsShares = superVault.convertToShares(maxWithdraw);
        uint256 maxRedeem = superVault.maxRedeem(_getActor());

        eq(maxWithdrawAsShares, maxRedeem, "maxWithdrawAsShares != maxRedeem");
    }

    /// @dev Property: requestRedeem should never reduce SuperVault shares
    function property_totalSharesDontDecreaseOnRedemptionRequest() public {
        if (_currentOp == OpType.REQUEST) {
            eq(
                _before.summedTotalShares,
                _after.summedTotalShares,
                "requestRedeem should never reduce SuperVault shares"
            );
        }
    }

    /// @dev Property: `SuperVault::totalSupply` == SUM(user balances) + balanceOf(escrow)
    function property_shareSolvency() public {
        eq(
            superVault.totalSupply(),
            _after.summedTotalShares,
            "vault shares are insolvent"
        );
    }

    /// @dev Property: balanceOf(escrow) >= SUM(controllers.pendingRedeemRequest)
    function property_escrowBalance() public {
        address[] memory actors = _getActors();

        uint256 escrowBalance = superVault.balanceOf(address(superVaultEscrow));
        uint256 pendingActorShares;
        for (uint256 i; i < actors.length; i++) {
            pendingActorShares += superVault.pendingRedeemRequest(0, actors[i]);
        }

        gte(
            escrowBalance,
            pendingActorShares,
            "balanceOf(escrow) < SUM(controllers.pendingRedeemRequest)"
        );
    }

    /// @dev Property: maxMint should be 0 when aggregator is paused
    function property_maxMintZeroWhenPaused() public {
        bool paused = superVaultAggregator.isStrategyPaused(
            address(superVaultStrategy)
        );
        uint256 maxMint = superVault.maxMint(_getActor());

        if (paused) {
            eq(maxMint, 0, "actor has nonzero maxMint when strategy is paused");
        }
    }

    /// @dev Property: maxDeposit should be 0 when strategy is paused
    function property_maxDepositZeroWhenPaused() public {
        bool paused = superVaultAggregator.isStrategyPaused(
            address(superVaultStrategy)
        );
        uint256 maxDeposit = superVault.maxDeposit(_getActor());

        if (paused) {
            eq(
                maxDeposit,
                0,
                "actor has nonzero maxDeposit when strategy is paused"
            );
        }
    }

    /// @dev Property: If user's maxWithdraw == 0 then getAverageWithdrawPrice for the user is also == 0
    function property_avgWithdrawPriceSanity() public {
        uint256 maxWithdraw = superVault.maxWithdraw(_getActor());
        uint256 avgWithdrawPrice = superVaultStrategy.getAverageWithdrawPrice(
            _getActor()
        );

        if (maxWithdraw == 0) {
            eq(
                avgWithdrawPrice,
                0,
                "getAverageWithdrawPrice != 0 when maxWithdraw == 0"
            );
        }
    }

    /// @dev Property: SUM(accumulatorShares) doesn't change on SuperVault share transfers
    function property_accumulatorSharesSolvency() public {
        if (_currentOp == OpType.TRANSFER) {
            eq(
                _before.summedAccumulatorShares,
                _after.summedAccumulatorShares,
                "SUM(accumulatorShares) changed on SuperVault share transfers"
            );
        }
    }

    /// @dev Property: SUM(accumulatorCostBasis) doesn't change on SuperVault share transfers
    function property_accumulatorCostBasisSolvency() public {
        if (_currentOp == OpType.TRANSFER) {
            eq(
                _before.summedAccumulatorCostBasis,
                _after.summedAccumulatorCostBasis,
                "SUM(accumulatorCostBasis) changed on SuperVault share transfers"
            );
        }
    }

    /// @dev Property: user cannot claim more assets than requested in redemption
    // NOTE: we test on a fulfillment because it's when pending shares are converted to assets
    function property_cannotClaimMoreThanRequested() public {
        if (_currentOp == OpType.FULFILL) {
            // pending decreases
            uint256 fulfilled = _before.pendingUserAssets[_getActor()] -
                _after.pendingUserAssets[_getActor()];
            // claimable increases
            uint256 claimable = _after.claimableUserAssets[_getActor()] -
                _before.claimableUserAssets[_getActor()];

            eq(
                fulfilled,
                claimable,
                "user cannot claim more assets than requested in redemption"
            );
        }
    }

    /// @dev Property: cancelRedeem should never alter the supply of SuperVault tokens
    function property_cancelDoesntChangeTotalSupply() public {
        if (_currentOp == OpType.CANCEL) {
            eq(
                _before.summedTotalShares,
                _after.summedTotalShares,
                "cancelRedeem should never alter the supply of SuperVault tokens"
            );
        }
    }

    /// @dev Property: if totalSupply > 0, then totalAssets > 0
    function property_assetBacking() public {
        if (superVault.totalSupply() > 0) {
            gt(
                _after.summedTotalAssets,
                0,
                "if totalSupply > 0, then totalAssets > 0"
            );
        }
    }

    /// @dev Property: SUM(shares) * PPS == totalAssets
    function property_totalAssets() public {
        uint256 totalShares = _sumTotalShares();
        uint256 pps = superVaultAggregator.getPPS(address(superVaultStrategy));
        uint256 implicitTotalAssets = (totalShares * pps) /
            superVault.PRECISION();

        uint256 vaultTotalAssets = superVault.totalAssets();
        eq(
            implicitTotalAssets,
            vaultTotalAssets,
            "totalShares * pps != totalAssets"
        );
    }

    /// @dev Property: When a user requests a redemption and the PPS is >= the user PPS, user averageRequestPPS must not decrease
    function property_avgPPSDoesntDecrease() public {
        uint256 currentPrice = _before.oraclePPS;
        uint256 avgPPS = _before.avgPPS[_getActor()];

        if (_currentOp == OpType.REQUEST && currentPrice >= avgPPS) {
            gte(
                _after.avgPPS[_getActor()],
                _before.avgPPS[_getActor()],
                "when a user requests a redemption and the PPS is >= the user PPS, user averageRequestPPS must not decrease"
            );
        }
    }

    /// Optimization Tests

    /// @dev Optimize the difference between the amount of assets in the system and claimable assets
    function optimize_maxDustAccumulation() public view returns (int256) {
        address[] memory actors = _getActors();

        uint256 summedClaimableRedemptionsAsAssets;
        for (uint256 i; i < actors.length; i++) {
            uint256 claimableRedemptions = superVault.claimableRedeemRequest(
                0,
                actors[i]
            );
            summedClaimableRedemptionsAsAssets += superVault.convertToAssets(
                claimableRedemptions
            );
        }

        uint256 totalAssets = _sumVaultAssets();

        return int256(totalAssets) - int256(summedClaimableRedemptionsAsAssets);
    }

    /// @dev Optimize the difference between the amount of claimable assets and assets in the system
    function optimize_maxClaimableDifference() public view returns (int256) {
        address[] memory actors = _getActors();

        uint256 summedClaimableRedemptionsAsAssets;
        for (uint256 i; i < actors.length; i++) {
            uint256 claimableRedemptions = superVault.claimableRedeemRequest(
                0,
                actors[i]
            );
            summedClaimableRedemptionsAsAssets += superVault.convertToAssets(
                claimableRedemptions
            );
        }

        uint256 totalAssets = _sumVaultAssets();

        return int256(summedClaimableRedemptionsAsAssets) - int256(totalAssets);
    }

    // Canaries
    function canary_executeHooksClamped() public {
        t(!executeHooksClampedSuccess);
    }

    function canary_executeHooks() public {
        t(!executeHooksSuccess);
    }
}
